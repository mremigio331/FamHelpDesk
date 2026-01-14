import React from "react";
import { useMobileDetection } from "../../provider/MobileDetectionProvider";
import GroupListItemDesktop from "./GroupListItemDesktop";
import GroupListItemMobile from "./GroupListItemMobile";

const GroupListItem = (props) => {
  const { isMobile } = useMobileDetection();

  return isMobile ? (
    <GroupListItemMobile {...props} />
  ) : (
    <GroupListItemDesktop {...props} />
  );
};

export default GroupListItem;
