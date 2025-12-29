import React from "react";
import { useMobileDetection } from "../../provider/MobileDetectionProvider";
import NotificationsPageDesktop from "./NotificationsPageDesktop";
import NotificationsPageMobile from "./NotificationsPageMobile";

const NotificationsPage = () => {
  const { isMobile } = useMobileDetection();

  return isMobile ? <NotificationsPageMobile /> : <NotificationsPageDesktop />;
};

export default NotificationsPage;
