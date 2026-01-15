import React from "react";
import { useMobileDetection } from "../../provider/MobileDetectionProvider";
import QueueListItemDesktop from "./QueueListItemDesktop";
import QueueListItemMobile from "./QueueListItemMobile";

const QueueListItem = (props) => {
  const { isMobile } = useMobileDetection();

  return isMobile ? (
    <QueueListItemMobile {...props} />
  ) : (
    <QueueListItemDesktop {...props} />
  );
};

export default QueueListItem;
