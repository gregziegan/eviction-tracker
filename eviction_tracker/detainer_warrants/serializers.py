from marshmallow import Schema, fields


class DistrictSchema(Schema):
    class Meta:
        fields = ("id", "name")


district_schema = DistrictSchema()
districts_schema = DistrictSchema(many=True)


class AttorneySchema(Schema):
    district = fields.Nested(DistrictSchema)

    class Meta:
        fields = ("id", "name", "district")


attorney_schema = AttorneySchema()
attorneys_schema = AttorneySchema(many=True)


class DefendantSchema(Schema):
    district = fields.Nested(DistrictSchema)

    class Meta:
        fields = ("id", "name", "district", "address")


defendant_schema = DefendantSchema()
defendants_schema = DefendantSchema(many=True)


class CourtroomSchema(Schema):
    district = fields.Nested(DistrictSchema)

    class Meta:
        fields = ("id", "name", "district")


courtroom_schema = CourtroomSchema()
courtrooms_schema = CourtroomSchema(many=True)


class PlantiffSchema(Schema):
    attorney = fields.Nested(AttorneySchema)
    district = fields.Nested(DistrictSchema)

    class Meta:
        fields = ("id", "name", "attorney", "district")


plantiff_schema = PlantiffSchema()
plantiffs_schema = PlantiffSchema(many=True)


class JudgeSchema(Schema):
    district = fields.Nested(DistrictSchema)

    class Meta:
        fields = ("id", "name", "district")


judge_schema = JudgeSchema()
judges_schema = JudgeSchema(many=True)


class DetainerWarrantSchema(Schema):
    plantiff = fields.Nested(PlantiffSchema)
    courtroom = fields.Nested(CourtroomSchema)
    presiding_judge = fields.Nested(JudgeSchema)
    defendants = fields.Nested(DefendantSchema, many=True)

    amount_claimed = fields.Float()

    class Meta:
        fields = ("docket_id", "file_date", "status", "court_date", "amount_claimed", "amount_claimed_category",
                  "judgement", "judgement_notes", "plantiff", "courtroom", "presiding_judge", "defendants",
                  "zip_code", "is_legacy", "is_cares")


detainer_warrant_schema = DetainerWarrantSchema()
detainer_warrants_schema = DetainerWarrantSchema(many=True)


class PhoneNumberVerificationSchema(Schema):
    class Meta:
        fields = ("caller_name", "caller_type", "error_code", "carrier",
                  "country_code", "national_format", "phone_number")


phone_number_verification_schema = PhoneNumberVerificationSchema()
phone_number_verifications_schema = PhoneNumberVerificationSchema(many=True)


class RoleSchema(Schema):
    class Meta:
        fields = ("id", "name", "description")


role_schema = RoleSchema()
roles_schemas = RoleSchema(many=True)


class UserSchema(Schema):
    roles = fields.Nested(RoleSchema, many=True)

    class Meta:
        fields = ("id", "name", "first_name", "last_name", "roles", "active")


user_schema = UserSchema()
user_schemas = UserSchema(many=True)
