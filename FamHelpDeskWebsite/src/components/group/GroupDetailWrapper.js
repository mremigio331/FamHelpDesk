import React from "react";
import { useMobileDetection } from "../../provider/MobileDetectionProvider";
import GroupDetailDesktop from "./GroupDetailDesktop";
import GroupDetailMobile from "./GroupDetailMobile";

/**
 * Wrapper component for GroupDetail that renders desktop or mobile version
 * based on device detection
 */
const GroupDetail = () => {
  const { isMobile } = useMobileDetection();

  return isMobile ? <GroupDetailMobile /> : <GroupDetailDesktop />;
};

export default GroupDetail;
