import operator
from flask import Blueprint
from flask_security import current_user 
from flask_resty import (
    ApiError,
    AuthorizeModifyMixin,
    HasAnyCredentialsAuthorization,
    HasCredentialsAuthorizationBase,
    HeaderAuthenticationBase,
    ColumnFilter,
    GenericModelView,
    CursorPaginationBase,
    RelayCursorPagination,
    Filtering,
    Sorting,
    meta,
    model_filter,
)

from sqlalchemy import and_, or_, func
from sqlalchemy.orm import raiseload
from sqlalchemy.exc import IntegrityError

from rdc_website.database import db
from .models import (
    DetainerWarrant,
    Attorney,
    Defendant,
    Courtroom,
    Hearing,
    Plaintiff,
    PleadingDocument,
    Judge,
    Judgment,
    PhoneNumberVerification,
)
from .serializers import *
from rdc_website.permissions.api import (
    HeaderUserAuthentication,
    Protected,
    PartnerProtected,
    OnlyMe,
    OnlyOrganizers,
    CursorPagination,
    AllowDefendant,
)
from psycopg2 import errors

UniqueViolation = errors.lookup("23505")


@model_filter(fields.String())
def filter_name(model, name):
    return model.name.ilike(f"%{name}%")


@model_filter(fields.String())
def filter_first_name(model, name):
    return model.first_name.ilike(f"%{name}%")


@model_filter(fields.String())
def filter_last_name(model, name):
    return model.last_name.ilike(f"%{name}%")


@model_filter(fields.String())
def filter_any_field(model, value):
    return or_(
        model._plaintiff.has(Plaintiff.name.ilike(f"%{value}%")),
        model._plaintiff_attorney.has(Attorney.name.ilike(f"%{value}%")),
        model._defendants.any(Defendant.name.ilike(f"%{value}%")),
    )


@model_filter(fields.String())
def filter_across_name_alias(model, value):
    return or_(
        model.name.ilike(f"%{value}%"),
        func.array_to_string(model.aliases, ",").ilike(f"%{value}%"),
    )


class AttorneyResourceBase(GenericModelView):
    model = Attorney
    schema = attorney_schema

    authentication = HeaderUserAuthentication()
    authorization = Protected()

    pagination = CursorPagination(default_limit=50, max_limit=100)
    sorting = Sorting("id", default="-id")
    filtering = Filtering(name=filter_name, free_text=filter_across_name_alias)


class AttorneyListResource(AttorneyResourceBase):
    def get(self):
        return self.list()

    def post(self):
        return self.create()


class AttorneyResource(AttorneyResourceBase):
    def get(self, id):
        return self.retrieve(id)

    def patch(self, id):
        return self.update(int(id), partial=True)


class DefendantResourceBase(GenericModelView):
    model = Defendant
    schema = defendant_schema

    authentication = HeaderUserAuthentication()
    authorization = OnlyOrganizers()

    pagination = CursorPagination(default_limit=50, max_limit=100)
    sorting = Sorting("id", default="-id")
    filtering = Filtering(
        first_name=filter_first_name, last_name=filter_last_name, name=filter_name
    )


class DefendantListResource(DefendantResourceBase):
    def get(self):
        return self.list()

    def post(self):
        return self.create()


class DefendantResource(DefendantResourceBase):
    def get(self, id):
        return self.retrieve(id)

    def patch(self, id):
        return self.update(int(id), partial=True)


class CourtroomResourceBase(GenericModelView):
    model = Courtroom
    schema = courtroom_schema

    authentication = HeaderUserAuthentication()
    authorization = Protected()

    pagination = CursorPagination(default_limit=50, max_limit=100)
    sorting = Sorting("id", default="-id")
    filtering = Filtering(
        name=filter_name,
    )


class CourtroomListResource(CourtroomResourceBase):
    def get(self):
        return self.list()

    def post(self):
        return self.create()


class CourtroomResource(CourtroomResourceBase):
    def get(self, id):
        return self.retrieve(id)

    def patch(self, id):
        return self.update(int(id), partial=True)


class PlaintiffResourceBase(GenericModelView):
    model = Plaintiff
    schema = plaintiff_schema

    authentication = HeaderUserAuthentication()
    authorization = Protected()

    pagination = CursorPagination(default_limit=50, max_limit=100)
    sorting = Sorting("id", default="-id")
    filtering = Filtering(name=filter_name, free_text=filter_across_name_alias)


class PlaintiffListResource(PlaintiffResourceBase):
    def get(self):
        return self.list()

    def post(self):
        return self.create()


class PlaintiffResource(PlaintiffResourceBase):
    def get(self, id):
        return self.retrieve(id)

    def patch(self, id):
        return self.update(int(id), partial=True)


class JudgeResourceBase(GenericModelView):
    model = Judge
    schema = judge_schema

    authentication = HeaderUserAuthentication()
    authorization = Protected()

    pagination = CursorPagination(default_limit=50, max_limit=100)
    sorting = Sorting("id", default="-id")
    filtering = Filtering(name=filter_name, free_text=filter_across_name_alias)


class JudgeListResource(JudgeResourceBase):
    def get(self):
        return self.list()

    def post(self):
        return self.create()


class JudgeResource(JudgeResourceBase):
    def get(self, id):
        return self.retrieve(id)

    def patch(self, id):
        return self.update(int(id), partial=True)


class JudgmentResourceBase(GenericModelView):
    model = Judgment
    schema = judgment_schema

    authentication = HeaderUserAuthentication()
    authorization = PartnerProtected()

    pagination = CursorPagination(default_limit=50, max_limit=100)
    sorting = Sorting("file_date", default="-file_date")


class JudgmentListResource(JudgmentResourceBase):
    def get(self):
        return self.list()

    def post(self):
        return self.create()


class JudgmentResource(JudgmentResourceBase):
    def get(self, id):
        return self.retrieve(id)

    def update_item(self, item, data):
        data["last_edited_by_id"] = current_user.id
        super().update_item(item, data)

    def patch(self, id):
        return self.update(int(id), partial=True)

    def delete(self, id):
        return self.destroy(int(id))


class HearingResourceBase(GenericModelView):
    model = Hearing
    schema = hearing_schema

    authentication = HeaderUserAuthentication()
    authorization = Protected()

    pagination = CursorPagination(default_limit=50, max_limit=100)
    sorting = Sorting("court_date", default="-court_date")


class HearingListResource(HearingResourceBase):
    def get(self):
        return self.list()

    def post(self):
        return self.create()


class HearingResource(HearingResourceBase):
    def get(self, id):
        return self.retrieve(id)

    def update_item(self, item, data):
        data["last_edited_by_id"] = current_user.id
        super().update_item(item, data)

    def patch(self, id):
        return self.update(int(id), partial=True)

    def delete(self, id):
        return self.destroy(int(id))


@model_filter(fields.String())
def filter_docket_id(model, id):
    return model.docket_id.ilike(f"%{id}%")


@model_filter(fields.Int())
def filter_defendant_id(model, id):
    return model._defendants.any(Defendant.id == id)


@model_filter(fields.String())
def filter_plaintiff_name(model, plaintiff_name):
    return model._plaintiff.has(Plaintiff.name.ilike(f"%{plaintiff_name}%"))


@model_filter(fields.String())
def filter_plaintiff_attorney_name(model, plaintiff_attorney_name):
    return model._plaintiff_attorney.has(
        Attorney.name.ilike(f"%{plaintiff_attorney_name}%")
    )


@model_filter(fields.Int())
def filter_court_date(model, court_date):
    return model.hearings.any(Hearing.court_date == court_date)


@model_filter(fields.String())
def filter_file_date(model, file_date_or_range):
    if "/" in file_date_or_range:
        start, end = file_date_or_range.split("/")
        return and_(model.file_date >= start, model.file_date <= end)
    else:
        return model.file_date == int(file_date_or_range)


@model_filter(fields.String(allow_none=True))
def filter_address(model, address):
    if address == "$NULL":
        return model.address == None
    else:
        return model.address.ilike(f"%{address}%")


class PleadingDocumentResourceBase(GenericModelView):
    model = PleadingDocument
    schema = pleading_document_schema
    id_fields = ("image_path",)

    authentication = HeaderUserAuthentication()
    authorization = OnlyOrganizers()

    pagination = CursorPagination(default_limit=50, max_limit=100)
    sorting = Sorting("updated_at", default="-updated_at")
    filtering = Filtering(docket_id=ColumnFilter(operator.eq))


class PleadingDocumentListResource(PleadingDocumentResourceBase):
    def get(self):
        return self.list()

    def post(self):
        return self.create()


class PleadingDocumentResource(PleadingDocumentResourceBase):
    def get(self, id):
        return self.retrieve(id)

    def patch(self, id):
        return self.update(int(id), partial=True)


class DetainerWarrantResourceBase(GenericModelView):
    model = DetainerWarrant
    schema = detainer_warrant_schema
    id_fields = ("docket_id",)

    authentication = HeaderUserAuthentication()
    authorization = PartnerProtected()

    pagination = CursorPagination(default_limit=50, max_limit=100)
    sorting = Sorting("order_number", default="-order_number")
    filtering = Filtering(
        docket_id=filter_docket_id,
        defendant_id=filter_defendant_id,
        order_number=operator.eq,
        file_date=filter_file_date,
        court_date=filter_court_date,
        plaintiff=filter_plaintiff_name,
        plaintiff_attorney=filter_plaintiff_attorney_name,
        address=filter_address,
        free_text=filter_any_field,
        audit_status=operator.eq,
    )


class DetainerWarrantListResource(DetainerWarrantResourceBase):
    def get(self):
        return self.list()


class DetainerWarrantResource(DetainerWarrantResourceBase):
    def get(self, id):
        return self.retrieve(id)

    def update_item(self, item, data):
        data["last_edited_by_id"] = current_user.id
        super().update_item(item, data)

    def patch(self, id):
        return self.upsert(id)


class PhoneNumberVerificationResourceBase(GenericModelView):
    model = PhoneNumberVerification
    schema = phone_number_verification_schema

    authentication = HeaderUserAuthentication()
    authorization = OnlyOrganizers()

    pagination = CursorPagination(default_limit=50, max_limit=100)
    sorting = Sorting("phone_number", default="phone_number")


class PhoneNumberVerificationListResource(PhoneNumberVerificationResourceBase):
    def get(self):
        return self.list()


class PhoneNumberVerificationResource(PhoneNumberVerificationResourceBase):
    def get(self, id):
        return self.retrieve(id)
