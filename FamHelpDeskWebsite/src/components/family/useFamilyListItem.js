import { useMemo } from "react";
import { useNavigate } from "react-router-dom";

/**
 * Shared logic for FamilyListItem components
 */
export const useFamilyListItem = ({ family, membership, actions }) => {
  const navigate = useNavigate();

  // Determine status based on membership
  const statusTag = useMemo(() => {
    if (!membership) return null;

    let statusColor = "green";
    let statusText = "Member";

    if (membership.status === "AWAITING") {
      statusColor = "orange";
      statusText = "Pending";
    } else if (membership.status === "DECLINED") {
      statusColor = "red";
      statusText = "Declined";
    }

    return { statusColor, statusText };
  }, [membership]);

  // Default actions if none provided
  const defaultActions = useMemo(() => {
    return (
      actions || [
        {
          key: "view",
          label: "View",
          onClick: (e) => {
            e.stopPropagation();
            navigate(`/family/${family.family_id}`);
          },
        },
      ]
    );
  }, [actions, family.family_id, navigate]);

  return {
    statusTag,
    defaultActions,
    navigate,
  };
};
