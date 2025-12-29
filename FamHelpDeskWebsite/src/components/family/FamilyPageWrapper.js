import React from "react";
import { useMobileDetection } from "../../provider/MobileDetectionProvider";
import FamilyPageDesktop from "./FamilyPageDesktop";
import FamilyPageMobile from "./FamilyPageMobile";

const FamilyPage = () => {
  const { isMobile } = useMobileDetection();

  return isMobile ? <FamilyPageMobile /> : <FamilyPageDesktop />;
};

export default FamilyPage;
