from pynamodb.attributes import UnicodeAttribute, BooleanAttribute, NumberAttribute
from pynamodb.indexes import GlobalSecondaryIndex, AllProjection
from models.base import FamHelpDeskBaseModel, MembershipStatus


class UserMembershipIndex(GlobalSecondaryIndex):
    class Meta:
        index_name = "UserMembershipIndex"
        projection = AllProjection()
        read_capacity_units = 5
        write_capacity_units = 5

    # Partition key: user_id for fast lookups of all memberships for a user
    user_id = UnicodeAttribute(hash_key=True)


class GroupMembershipModel(FamHelpDeskBaseModel):
    family_id = UnicodeAttribute()
    group_id = UnicodeAttribute()
    user_id = UnicodeAttribute()
    status = UnicodeAttribute()
    is_admin = BooleanAttribute()
    request_date = NumberAttribute()

    # GSI for querying by user_id
    user_index = UserMembershipIndex()

    @staticmethod
    def create_pk(family_id: str) -> str:
        return f"FAMILY#{family_id}"

    @staticmethod
    def create_sk(group_id: str, user_id: str) -> str:
        return f"GROUP#{group_id}#MEMBER#{user_id}"
