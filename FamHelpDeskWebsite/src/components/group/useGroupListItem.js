import { useMemo } from "react";

/**
 * Custom hook for GroupListItem logic
 * Handles membership status display and default actions
 */
const useGroupListItem = ({ group, membership, actions }) => {
  // Determine membership status tag
  const statusTag = useMemo(() => {
    if (!membership) {
      return {
        statusText: "Not a Member",
        statusColor: "default",
      };
    }

    switch (membership.status) {
      case "ACTIVE":
        return membership.is_admin
          ? {
              statusText: "Admin",
              statusColor: "blue",
            }
          : {
              statusText: "Member",
              statusColor: "green",
            };
      case "PENDING":
        return {
          statusText: "Pending",
          statusColor: "orange",
        };
      case "REJECTED":
        return {
          statusText: "Rejected",
          statusColor: "red",
        };
      default:
        return {
          statusText: membership.status,
          statusColor: "default",
        };
    }
  }, [membership]);

  // Default actions if none provided
  const defaultActions = useMemo(() => {
    if (actions) return [];

    const actionsList = [];

    if (membership?.status === "ACTIVE") {
      actionsList.push({
        key: "view",
        label: "View",
        onClick: (e) => {
          e.stopPropagation();
          // Default view action - can be overridden by parent
        },
      });

      if (membership.is_admin) {
        actionsList.push({
          key: "manage",
          label: "Manage",
          onClick: (e) => {
            e.stopPropagation();
            // Default manage action - can be overridden by parent
          },
        });
      }
    }
    // Removed "Request to Join" button - users should request from group detail page

    return actionsList;
  }, [membership, actions]);

  return {
    statusTag,
    defaultActions,
  };
};

export { useGroupListItem };
