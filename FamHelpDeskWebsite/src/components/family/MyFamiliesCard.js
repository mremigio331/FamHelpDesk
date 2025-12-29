import React from "react";
import { useMobileDetection } from "../../provider/MobileDetectionProvider";
import MyFamiliesCardDesktop from "./MyFamiliesCardDesktop";
import MyFamiliesCardMobile from "./MyFamiliesCardMobile";

const MyFamiliesCard = () => {
  const { isMobile } = useMobileDetection();

  return isMobile ? <MyFamiliesCardMobile /> : <MyFamiliesCardDesktop />;
};

export default MyFamiliesCard;
