import { useState, useMemo } from "react";
import { message } from "antd";
import {
  isActualMember,
  hasPendingRequest,
} from "../../../utility/familyUtils";

/**
 * Shared logic for FindFamily components
 */
export const useFindFamily = ({
  families,
  myFamilies,
  requestFamilyMembership,
  isRequesting,
}) => {
  const [searchQuery, setSearchQuery] = useState("");
  const [requestedFamilies, setRequestedFamilies] = useState(new Set());

  const handleRequestMembership = (familyId) => {
    requestFamilyMembership(
      { familyId },
      {
        onSuccess: () => {
          message.success("Membership request sent successfully!");
          setRequestedFamilies((prev) => new Set([...prev, familyId]));
        },
        onError: (error) => {
          message.error(
            error?.response?.data?.detail || "Failed to request membership",
          );
        },
      },
    );
  };

  // Filter families based on search query
  const filteredFamilies = useMemo(() => {
    return families.filter((family) => {
      const query = searchQuery.toLowerCase();
      return (
        family.family_name.toLowerCase().includes(query) ||
        (family.family_description &&
          family.family_description.toLowerCase().includes(query))
      );
    });
  }, [families, searchQuery]);

  // Separate families into member and non-member
  const { memberFamilies, availableFamilies } = useMemo(() => {
    return filteredFamilies.reduce(
      (acc, family) => {
        if (isActualMember(family.family_id, myFamilies)) {
          acc.memberFamilies.push(family);
        } else {
          acc.availableFamilies.push(family);
        }
        return acc;
      },
      { memberFamilies: [], availableFamilies: [] },
    );
  }, [filteredFamilies, myFamilies]);

  // Generate actions for family list items
  const createFamilyActions = (family, navigate) => {
    const isMember = isActualMember(family.family_id, myFamilies);
    const isPending = hasPendingRequest(family.family_id, myFamilies);
    const hasJustRequested = requestedFamilies.has(family.family_id);

    return {
      isMember,
      isPending,
      hasJustRequested,
      isDisabled: isPending || hasJustRequested,
      buttonText:
        isPending || hasJustRequested ? "Request Sent" : "Request to Join",
      onRequestJoin: () => handleRequestMembership(family.family_id),
      onView: () => navigate(`/family/${family.family_id}`),
    };
  };

  return {
    searchQuery,
    setSearchQuery,
    memberFamilies,
    availableFamilies,
    createFamilyActions,
    isRequesting,
  };
};
