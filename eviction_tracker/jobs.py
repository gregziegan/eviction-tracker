import time
from datetime import datetime, date, timedelta
from apscheduler.triggers.interval import IntervalTrigger
from sqlalchemy import and_

import eviction_tracker.detainer_warrants as detainer_warrants
from eviction_tracker.detainer_warrants.models import DetainerWarrant
from eviction_tracker.extensions import db, scheduler

import eviction_tracker.config as config
import logging.config

logging.config.dictConfig(config.LOGGING)
logger = logging.getLogger(__name__)


def export():
    with scheduler.app.app_context():
        workbook_name = 'Website Export'
        key = scheduler.app.config['GOOGLE_ACCOUNT_PATH']
        logger.info(
            f'Exporting detainer warrants to workbook: {workbook_name}')
        detainer_warrants.exports.to_spreadsheet(workbook_name, key)
        logger.info(f'Exporting judgements to workbook: {workbook_name}')
        detainer_warrants.exports.to_judgement_sheet(workbook_name, key)
        logger.info(
            f'Exporting upcoming court dates to workbook: {workbook_name}')
        detainer_warrants.exports.to_court_watch_sheet(workbook_name, key)
        courtroom_entry_wb = f'{datetime.strftime(date.today(), "%B %Y")} Court Watch'
        logger.info(
            f'Exporting the week\'s to workbook: {courtroom_entry_wb}')
        detainer_warrants.exports.weekly_courtroom_entry_workbook(
            date.today(), key)


def import_caselink_warrants(start_date=None, end_date=None):
    start = datetime.strptime(
        start_date, '%Y-%m-%d') if start_date else date.today()
    end = datetime.strptime(end_date, '%Y-%m-%d') if end_date else date.today()

    with scheduler.app.app_context():
        detainer_warrants.caselink.warrants.import_from_caselink(start, end)


def import_caselink_pleading_documents():
    with scheduler.app.app_context():
        queue = db.session.query(DetainerWarrant.docket_id).filter(and_(
            DetainerWarrant.docket_id.ilike('%GT%'),
            DetainerWarrant.status == 'PENDING'
        ))
        detainer_warrants.caselink.pleadings.bulk_import_documents(queue)


def import_sessions_site_hearings():
    with scheduler.app.app_context():
        logger.info(f'Scraping General Sessions website')
        detainer_warrants.judgement_scraping.scrape_entire_site()
