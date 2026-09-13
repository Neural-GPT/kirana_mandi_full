"""
Seeds reference/catalog data only -- shop categories, product categories,
service options, and the bundled icon library. Mirrors the Flutter app's
seed_data.dart, which deliberately does NOT seed demo regions or shops:
every area comes from an admin or a shopkeeper, and every shop comes from
a real shopkeeper signup.

Safe to run repeatedly -- skips anything already present by id/name.
"""
from sqlalchemy.orm import Session

from . import models
from .database import Base, SessionLocal, engine

SHOP_CATEGORIES = [
    "General Store", "Dairy", "Vegetables & Fruits", "Stationery",
    "Bakery", "Meat & Fish", "Pharmacy", "Hardware",
]
PRODUCT_CATEGORIES = [
    "Grocery", "Dairy", "Snacks", "Personal Care", "Household",
    "Vegetables", "Fruits", "Stationery", "Bakery",
]
SERVICES = ["Home Delivery", "Phone Orders", "Cash on Delivery", "UPI Accepted"]

# Must match the ids in the Flutter app's IconRegistry
# (lib/core/constants/icon_registry.dart) exactly -- these ids are what
# get stored on a product/shop, resolved to a bundled Material icon on
# the client. This backend only carries the id + a human label so an
# admin can browse/manage which icons are offered; it never renders them.
ICON_IDS = [
    "rice_01", "wheat_01", "flour_01", "pulses_01", "sugar_01", "oil_01", "spices_01",
    "milk_01", "curd_01", "butter_01", "cheese_01", "paneer_01",
    "soap_01", "shampoo_01", "toothpaste_01", "toothbrush_01",
    "water_01", "juice_01", "soft_drink_01", "tea_01", "coffee_01",
    "vegetables_01", "fruits_01", "onion_01", "potato_01",
    "biscuits_01", "chips_01", "namkeen_01", "chocolate_01",
    "detergent_01", "cleaning_01", "broom_01", "bulb_01",
    "notebook_01", "pen_01",
    "generic_item_01",
]


def _label_for(icon_id: str) -> str:
    return icon_id.replace("_01", "").replace("_", " ").title()


def seed(db: Session) -> None:
    existing_categories = {(c.name, c.type) for c in db.query(models.Category).all()}
    for name in SHOP_CATEGORIES:
        if (name, "shop") not in existing_categories:
            db.add(models.Category(name=name, type="shop"))
    for name in PRODUCT_CATEGORIES:
        if (name, "product") not in existing_categories:
            db.add(models.Category(name=name, type="product"))

    existing_services = {s.name for s in db.query(models.ServiceOption).all()}
    for name in SERVICES:
        if name not in existing_services:
            db.add(models.ServiceOption(name=name))

    existing_icon_ids = {i.id for i in db.query(models.ProductIcon).all()}
    for icon_id in ICON_IDS:
        if icon_id not in existing_icon_ids:
            db.add(models.ProductIcon(id=icon_id, label=_label_for(icon_id)))

    db.commit()


def main() -> None:
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        seed(db)
        print("Seed complete.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
