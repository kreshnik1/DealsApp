from app.worker.celery import celery_app


@celery_app.task(name="app.worker.tasks.scrape_willys")
def scrape_willys(lat: float, lon: float):
    from app.db.session import SessionLocal
    from app.scrapers import willys

    db = SessionLocal()
    try:
        count = willys.scrape(db, lat=lat, lon=lon)
        return {"deals_saved": count}
    finally:
        db.close()
