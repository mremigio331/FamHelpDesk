from dataclasses import dataclass, asdict
from typing import Optional, List, Dict, Any
import re
from models.base import FamHelpDeskBaseModel


@dataclass
class EntityRef:
    """
    Represents a reference to an entity that can be enriched with its name
    """

    id: str
    name: Optional[str] = "Deleted Entity"

    def to_dict(self) -> dict:
        return {"id": self.id, "name": self.name}


class EntityRefHelper:
    """
    Helper class for enriching EntityRef objects with names from the GSI
    """

    @staticmethod
    def extract_uuids_from_text(text: str) -> List[str]:
        """
        Extract all UUIDs and entity IDs from text using regex patterns.
        Returns list of unique IDs found in the text.

        Supports:
        - Standard UUIDs: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
        - Family IDs: F followed by digits (e.g., F3627302529)
        - Group IDs: G followed by digits (e.g., G654564843)

        Args:
            text: The text to extract IDs from

        Returns:
            List of unique ID strings found in the text
        """
        # Standard UUID pattern
        uuid_pattern = r"[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}"

        # Family ID pattern: F followed by digits
        family_id_pattern = r"F\d+"

        # Group ID pattern: G followed by digits
        group_id_pattern = r"G\d+"

        # Find all matches
        all_ids = []
        all_ids.extend(re.findall(uuid_pattern, text, re.IGNORECASE))
        all_ids.extend(re.findall(family_id_pattern, text))
        all_ids.extend(re.findall(group_id_pattern, text))

        # Return unique IDs
        return list(set(all_ids))

    @staticmethod
    def resolve_uuids_in_text(text: str, entity_lookup: Dict[str, str]) -> str:
        """
        Replace UUIDs and entity IDs in text with entity names from lookup dict.

        Supports:
        - Standard UUIDs: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
        - Family IDs: F followed by digits (e.g., F3627302529)
        - Group IDs: G followed by digits (e.g., G654564843)

        Args:
            text: The text containing UUIDs/IDs
            entity_lookup: Dict mapping UUID/ID -> display_name

        Returns:
            Text with UUIDs/IDs replaced by display names where available
        """
        # Create a combined pattern that matches all ID types
        combined_pattern = (
            r"([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}|F\d+|G\d+)"
        )

        def replace_id(match):
            entity_id = match.group(0)
            # Check if this ID should be resolved
            if entity_id in entity_lookup:
                return entity_lookup[entity_id]
            else:
                # Don't resolve - could be a ticket ID or unknown entity
                return entity_id

        return re.sub(combined_pattern, replace_id, text, flags=re.IGNORECASE)

    @staticmethod
    def enrich_entity_refs(data: Any) -> Any:
        """
        Takes any data structure and enriches all EntityRef objects with names

        Args:
            data: Can be a dict, list, or any nested structure containing EntityRef objects

        Returns:
            The same data structure with EntityRef objects populated with names and converted to dicts
        """
        # Collect all EntityRef objects
        entity_refs = []
        EntityRefHelper._collect_entity_refs(data, entity_refs)

        if not entity_refs:
            return EntityRefHelper._convert_entity_refs_to_dicts(data)

        # Get unique IDs to avoid duplicate lookups
        unique_ids = list(set(ref.id for ref in entity_refs if ref.id))

        if not unique_ids:
            return EntityRefHelper._convert_entity_refs_to_dicts(data)

        # Batch lookup names from GSI
        name_cache = EntityRefHelper._batch_lookup_names(unique_ids)

        # Populate names
        for ref in entity_refs:
            if ref.id in name_cache:
                ref.name = name_cache[ref.id]

        # Convert EntityRef objects to dicts for JSON serialization
        return EntityRefHelper._convert_entity_refs_to_dicts(data)

    @staticmethod
    def _collect_entity_refs(obj: Any, refs_list: List[EntityRef]) -> None:
        """
        Recursively find all EntityRef objects in a data structure

        Args:
            obj: The object to search through
            refs_list: List to append found EntityRef objects to
        """
        if isinstance(obj, EntityRef):
            refs_list.append(obj)
        elif isinstance(obj, dict):
            for value in obj.values():
                EntityRefHelper._collect_entity_refs(value, refs_list)
        elif isinstance(obj, list):
            for item in obj:
                EntityRefHelper._collect_entity_refs(item, refs_list)

    @staticmethod
    def _convert_entity_refs_to_dicts(obj: Any) -> Any:
        """
        Convert all EntityRef objects to dictionaries for JSON serialization

        Args:
            obj: The object to convert

        Returns:
            The object with EntityRef objects converted to dicts
        """
        if isinstance(obj, EntityRef):
            return obj.to_dict()
        elif isinstance(obj, dict):
            return {
                key: EntityRefHelper._convert_entity_refs_to_dicts(value)
                for key, value in obj.items()
            }
        elif isinstance(obj, list):
            return [EntityRefHelper._convert_entity_refs_to_dicts(item) for item in obj]
        else:
            return obj

    @staticmethod
    def _batch_lookup_names(ids: List[str]) -> Dict[str, str]:
        """
        Batch lookup names from the entity lookup GSI

        Args:
            ids: List of entity UUIDs to lookup

        Returns:
            Dictionary mapping UUID to name
        """
        if not ids:
            return {}

        try:
            # Import here to avoid circular imports
            from models.family import FamilyModel

            name_cache = {}

            # Query the GSI for each entity ID
            for entity_id in ids:
                try:
                    # Query the GSI for this specific entity
                    results = list(
                        FamilyModel.entity_lookup_index.query(entity_id, limit=1)
                    )

                    if results:
                        name_cache[entity_id] = results[0].entity_name

                except Exception as e:
                    # Log the error but continue with other lookups
                    print(f"Error looking up entity {entity_id}: {e}")
                    continue

            return name_cache

        except Exception as e:
            print(f"Error in batch lookup: {e}")
            return {}
