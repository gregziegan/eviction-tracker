from nameparser import HumanName
from pyquery import PyQuery as pq
import re
import requests
from sqlalchemy.exc import IntegrityError, InternalError
from sqlalchemy.dialects.postgresql import insert

from .models import db
from .models import Attorney, Courtroom, Defendant, DetainerWarrant, District, Judge, Plaintiff, detainer_warrant_defendants
from .util import get_or_create, normalize

SITE = "http://circuitclerk.nashville.gov/dockets/viewdocket_c.asp"

DDID = "ddid"
DATE = "date"
TIME = "time"
LOC = "loc"
SN = "sn"
SN2 = "sn2"

DOCKET_INDEX = 0
CONT_INDEX = 17
PLAINTIFF_INDEX = 28
DEFENDANT_INDEX = 77
PLAINTIFF_ATTORNEY_INDEX = 148
DEFENDANT_ADDRESS_INDEX = 197
DEFENDANT_ADDRESS_2_INDEX = 315
DEFENDANT_ADDRESS_3_INDEX = 400

COURTROOMS = {
    '1A': 91,
    '1B': 73
}

LOCATIONS = {
    '1A': 72,
    '1B': 12
}


def create_defendant(defaults, listing):
    if 'ALL OTHER OCCUPANTS' in listing['name']:
        return None

    name = HumanName(listing['name'].replace('OR ALL OCCUPANTS', ''))
    address = listing['address']

    defendant = None
    if name.first:
        defendant, _ = get_or_create(
            db.session, Defendant,
            first_name=name.first,
            middle_name=name.middle,
            last_name=name.last,
            suffix=name.suffix,
            address=address,
            defaults=defaults
        )

    return defendant


def link_defendant(docket_id, defendant):
    db.session.execute(insert(detainer_warrant_defendants)
                       .values(detainer_warrant_docket_id=docket_id, defendant_id=defendant.id))


def insert_warrant(defaults, docket_id, listing):
    attorney = None
    if listing['plaintiff_attorney']:
        attorney, _ = get_or_create(
            db.session, Attorney, name=listing['plaintiff_attorney'], defaults=defaults)

    plaintiff = None
    if listing['plaintiff']:
        plaintiff, _ = get_or_create(
            db.session, Plaintiff, name=listing['plaintiff'], defaults=defaults)

    court_date = listing['court_date']

    courtroom = None
    if listing['courtroom']:
        courtroom, _ = get_or_create(
            db.session, Courtroom, name=listing['courtroom'], defaults=defaults)

    defendants = [create_defendant(defaults, defendant)
                  for defendant in listing['defendants']]

    dw_values = dict(docket_id=docket_id,
                     plaintiff_id=plaintiff.id if plaintiff else None,
                     plaintiff_attorney_id=attorney.id if attorney else None,
                     court_date=court_date,
                     courtroom_id=courtroom.id if courtroom else None
                     )

    insert_stmt = insert(DetainerWarrant).values(
        **dw_values
    )

    do_update_stmt = insert_stmt.on_conflict_do_update(
        constraint=DetainerWarrant.__table__.primary_key,
        set_=dw_values
    )

    db.session.execute(do_update_stmt)
    db.session.commit()

    try:
        for defendant in defendants:
            if defendant:
                link_defendant(docket_id, defendant)

    except IntegrityError:
        pass

    db.session.commit()


def scrape(courtroom, date):
    r = requests.get(SITE, params={
        DDID: COURTROOMS[courtroom],
        DATE: date,
        TIME: '10:00',
        LOC: LOCATIONS[courtroom],
        SN: 2,
        SN2: 3
    })
    d = pq(r.text)
    content = d("pre").eq(0).text(squash_space=False)

    cur_detainer_id = None
    detainers = {}
    for dw in re.sub(r'\r\n', '', re.sub(r'-{4,}', '|', content)).split('|'):
        if dw[DOCKET_INDEX] != ' ':  # new docket
            cur_detainer_id = dw[DOCKET_INDEX:CONT_INDEX].strip()
            detainers[cur_detainer_id] = {
                'plaintiff': dw[PLAINTIFF_INDEX:DEFENDANT_INDEX].strip(),
                'plaintiff_attorney': dw[PLAINTIFF_ATTORNEY_INDEX:DEFENDANT_ADDRESS_2_INDEX],
                'defendants': [{
                    'name': dw[DEFENDANT_INDEX:PLAINTIFF_ATTORNEY_INDEX].strip(),
                    'address': re.sub(r'[ ]{3,}', '', dw[DEFENDANT_ADDRESS_INDEX:]).strip()
                }],
                'court_date': date,
                'courtroom': courtroom
            }
        elif 'GENERAL SESSIONS' in dw:
            continue
        else:  # still in an existing docket entry
            detainers[cur_detainer_id]['defendants'].append({
                'name': dw[DEFENDANT_INDEX:PLAINTIFF_ATTORNEY_INDEX].strip(),
                'address': re.sub(r'[ ]{3,}', '', dw[DEFENDANT_ADDRESS_INDEX:]).strip()
            })

    district, _ = get_or_create(db.session, District, name="Davidson County")

    db.session.add(district)
    db.session.commit()

    defaults = {'district': district}

    for docket_id, listing in detainers.items():
        insert_warrant(defaults, docket_id, listing)
