from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload

from .. import models, schemas
from ..constants import (
    ACTIVE_ORDER_STATUSES,
    ADMIN_ROLES,
    ROLE_CUSTOMER,
    ROLE_SHOPKEEPER,
    SHOPKEEPER_STATUS_TRANSITIONS,
    STATUS_CANCELLED,
    STATUS_PLACED,
)
from ..database import get_db
from ..deps import get_current_user, require_roles

router = APIRouter(tags=["cart & orders"])


# --- Cart ---
@router.get("/cart", response_model=list[schemas.CartItemOut])
def get_cart(
    db: Session = Depends(get_db),
    user: models.User = Depends(require_roles(ROLE_CUSTOMER)),
):
    return (
        db.query(models.CartItem)
        .filter(models.CartItem.customer_id == user.id)
        .order_by(models.CartItem.shop_name, models.CartItem.added_at)
        .all()
    )


@router.post("/cart/items", response_model=schemas.CartItemOut)
def add_or_increment_cart_item(
    body: schemas.CartItemUpsert,
    db: Session = Depends(get_db),
    user: models.User = Depends(require_roles(ROLE_CUSTOMER)),
):
    existing = (
        db.query(models.CartItem)
        .filter(models.CartItem.customer_id == user.id, models.CartItem.product_id == body.product_id)
        .first()
    )
    if existing:
        existing.quantity += body.quantity
        db.commit()
        db.refresh(existing)
        return existing

    item = models.CartItem(customer_id=user.id, **body.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.patch("/cart/items/{product_id}", response_model=schemas.CartItemOut | None)
def set_cart_item_quantity(
    product_id: str,
    body: schemas.CartQuantityUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(require_roles(ROLE_CUSTOMER)),
):
    item = (
        db.query(models.CartItem)
        .filter(models.CartItem.customer_id == user.id, models.CartItem.product_id == product_id)
        .first()
    )
    if item is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Not in cart.")
    if body.quantity <= 0:
        db.delete(item)
        db.commit()
        return None
    item.quantity = body.quantity
    db.commit()
    db.refresh(item)
    return item


@router.delete("/cart/items/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_cart_item(
    product_id: str,
    db: Session = Depends(get_db),
    user: models.User = Depends(require_roles(ROLE_CUSTOMER)),
):
    db.query(models.CartItem).filter(
        models.CartItem.customer_id == user.id, models.CartItem.product_id == product_id
    ).delete()
    db.commit()


# --- Checkout / Orders ---
@router.post("/orders/checkout", response_model=list[schemas.OrderOut])
def checkout(
    body: schemas.CheckoutRequest,
    db: Session = Depends(get_db),
    user: models.User = Depends(require_roles(ROLE_CUSTOMER)),
):
    """
    Places one order per shop group in the customer's cart (or just the
    requested `shop_ids`, if given), then clears those shops' items out
    of the cart. Mirrors the mobile app's "cart grouped by shop, one
    order per shop" checkout.
    """
    q = db.query(models.CartItem).filter(models.CartItem.customer_id == user.id)
    if body.shop_ids:
        q = q.filter(models.CartItem.shop_id.in_(body.shop_ids))
    cart_items = q.all()
    if not cart_items:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Your cart is empty.")

    by_shop: dict[str, list[models.CartItem]] = {}
    for item in cart_items:
        by_shop.setdefault(item.shop_id, []).append(item)

    created_orders: list[models.Order] = []
    for shop_id, items in by_shop.items():
        shop = db.get(models.Shop, shop_id)
        if shop is None:
            continue
        total = sum(i.unit_price * i.quantity for i in items)

        order = models.Order(
            customer_id=user.id,
            customer_name=user.name or "Customer",
            customer_phone=user.phone,
            shop_id=shop_id,
            shop_name=shop.name,
            shop_phone=shop.phone,
            status=STATUS_PLACED,
            total_amount=total,
        )
        db.add(order)
        db.flush()  # get order.id before creating items

        for cart_item in items:
            db.add(
                models.OrderItem(
                    order_id=order.id,
                    product_id=cart_item.product_id,
                    product_name=cart_item.product_name,
                    unit=cart_item.unit,
                    unit_price=cart_item.unit_price,
                    quantity=cart_item.quantity,
                )
            )
            db.delete(cart_item)

        created_orders.append(order)

    db.commit()
    for order in created_orders:
        db.refresh(order)
    return created_orders


@router.get("/orders/mine", response_model=list[schemas.OrderOut])
def my_orders(
    db: Session = Depends(get_db),
    user: models.User = Depends(require_roles(ROLE_CUSTOMER)),
):
    return (
        db.query(models.Order)
        .options(joinedload(models.Order.items))
        .filter(models.Order.customer_id == user.id)
        .order_by(models.Order.created_at.desc())
        .all()
    )


@router.get("/orders/{order_id}", response_model=schemas.OrderOut)
def get_order(
    order_id: str,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    order = (
        db.query(models.Order)
        .options(joinedload(models.Order.items))
        .filter(models.Order.id == order_id)
        .first()
    )
    if order is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found.")
    if user.role not in ADMIN_ROLES and order.customer_id != user.id:
        shop = db.get(models.Shop, order.shop_id)
        if shop is None or shop.owner_user_id != user.id:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your order.")
    return order


@router.get("/shops/{shop_id}/orders", response_model=list[schemas.OrderOut])
def shop_orders(
    shop_id: str,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    shop = db.get(models.Shop, shop_id)
    if shop is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Shop not found.")
    if user.role not in ADMIN_ROLES and shop.owner_user_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You don't own this shop.")

    return (
        db.query(models.Order)
        .options(joinedload(models.Order.items))
        .filter(models.Order.shop_id == shop_id)
        .order_by(models.Order.created_at.desc())
        .all()
    )


@router.patch("/orders/{order_id}/status", response_model=schemas.OrderOut)
def update_order_status(
    order_id: str,
    body: schemas.OrderStatusUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    order = db.get(models.Order, order_id)
    if order is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found.")
    shop = db.get(models.Shop, order.shop_id)

    if user.role in ADMIN_ROLES:
        pass  # admins can force any transition (support/dispute handling)
    elif user.role == ROLE_SHOPKEEPER:
        if shop.owner_user_id != user.id:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "You don't own this shop.")
        allowed = SHOPKEEPER_STATUS_TRANSITIONS.get(order.status, set())
        # A shopkeeper may also re-submit the SAME status purely to
        # update delivery_boy_phone (the mobile app's "Edit Delivery
        # Phone" action, shown while an order is already
        # out_for_delivery) -- that's not a state transition, so it's
        # allowed even though it's not in the forward-transition table.
        if body.status != order.status and body.status not in allowed:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                f"Can't move an order from '{order.status}' to '{body.status}'.",
            )
    else:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Only the shop or an admin can update order status.")

    order.status = body.status
    if body.delivery_boy_phone:
        order.delivery_boy_phone = body.delivery_boy_phone
    db.commit()
    db.refresh(order)
    return order


@router.post("/orders/{order_id}/cancel", response_model=schemas.OrderOut)
def cancel_order(
    order_id: str,
    db: Session = Depends(get_db),
    user: models.User = Depends(require_roles(ROLE_CUSTOMER)),
):
    order = db.get(models.Order, order_id)
    if order is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found.")
    if order.customer_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "This is not your order.")
    if order.status not in ACTIVE_ORDER_STATUSES:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "This order can no longer be cancelled.")
    order.status = STATUS_CANCELLED
    db.commit()
    db.refresh(order)
    return order
