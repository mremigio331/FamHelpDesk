from pynamodb.attributes import UnicodeAttribute
from pynamodb.indexes import GlobalSecondaryIndex, AllProjection


class EntityLookupIndex(GlobalSecondaryIndex):
    """
    GSI for looking up entity names by UUID
    PK: entity_uuid (the UUID of the entity)
    SK: entity_name (the display name of the entity)

    This GSI allows efficient batch lookup of entity names by their UUIDs
    for use in ticket display and other UI components.
    """

    class Meta:
        index_name = "entity-name-lookup-index"  # Match CDK name
        projection = AllProjection()

    entity_uuid = UnicodeAttribute(hash_key=True)
    entity_name = UnicodeAttribute(range_key=True)
