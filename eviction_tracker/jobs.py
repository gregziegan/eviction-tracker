import time
from datetime import datetime, date, timedelta
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger

import eviction_tracker.detainer_warrants as detainer_warrants
from eviction_tracker.extensions import scheduler

import eviction_tracker.config as config
import logging.config

logging.config.dictConfig(config.LOGGING)
logger = logging.getLogger(__name__)

weekdays = '1-5'


@scheduler.task(IntervalTrigger(minutes=70), id='export')
def export():
    with scheduler.app.app_context():
        workbook_name = 'Website Export'
        key = scheduler.app.config['GOOGLE_ACCOUNT_PATH']
        logger.info(
            f'Exporting detainer warrants to workbook: {workbook_name}')
        detainer_warrants.exports.to_spreadsheet(workbook_name, key)
        logger.info(f'Exporting judgments to workbook: {workbook_name}')
        detainer_warrants.exports.to_judgment_sheet(workbook_name, key)
        logger.info(
            f'Exporting upcoming court dates to workbook: {workbook_name}')
        detainer_warrants.exports.to_court_watch_sheet(workbook_name, key)
        courtroom_entry_wb = f'{datetime.strftime(date.today(), "%B %Y")} Court Watch'
        logger.info(
            f'Exporting the week\'s to workbook: {courtroom_entry_wb}')
        detainer_warrants.exports.weekly_courtroom_entry_workbook(
            date.today(), key)


@scheduler.task(CronTrigger(day_of_week=weekdays, hour=12, minute=0, second=0, jitter=200), id='import-caselink-warrants')
def import_caselink_warrants(start_date=None, end_date=None):
    start = datetime.strptime(
        start_date, '%Y-%m-%d') if start_date else date.today()
    end = datetime.strptime(end_date, '%Y-%m-%d') if end_date else date.today()

    with scheduler.app.app_context():
        detainer_warrants.caselink.warrants.import_from_caselink(start, end)


@scheduler.task(CronTrigger(day_of_week=weekdays, hour=5, minute=0, second=0, jitter=200), id='import-caselink-pleading-documents')
def import_caselink_pleading_documents():
    with scheduler.app.app_context():
        detainer_warrants.caselink.pleadings.update_pending_warrants()


@scheduler.task(CronTrigger(day_of_week=weekdays, hour=9, minute=0, second=0, jitter=200), id='extract-pleading-document-details')
def extract_pleading_document_details():
    with scheduler.app.app_context():
        detainer_warrants.caselink.pleadings.bulk_extract_pleading_document_details()


@scheduler.task(CronTrigger(day_of_week=weekdays, hour=10, minute=0, second=0), id='sync-with-sessions-site')
def import_sessions_site_hearings():
    with scheduler.app.app_context():
        logger.info(f'Scraping General Sessions website')
        detainer_warrants.judgment_scraping.scrape_entire_site()
