import React from "react";
import { useMobileDetection } from "../../provider/MobileDetectionProvider";
import FamilyListItemDesktop from "./FamilyListItemDesktop";
import FamilyListItemMobile from "./FamilyListItemMobile";

const FamilyListItem = (props) => {
  const { isMobile } = useMobileDetection();

  return isMobile ? (
    <FamilyListItemMobile {...props} />
  ) : (
    <FamilyListItemDesktop {...props} />
  );
};

export default FamilyListItem;
