import React from "react";
import { useMobileDetection } from "../../provider/MobileDetectionProvider";
import QueueDetailDesktop from "./QueueDetailDesktop";
import QueueDetailMobile from "./QueueDetailMobile";

/**
 * Wrapper component for QueueDetail that renders desktop or mobile version
 * based on device detection
 */
const QueueDetail = () => {
  const { isMobile } = useMobileDetection();

  return isMobile ? <QueueDetailMobile /> : <QueueDetailDesktop />;
};

export default QueueDetail;
