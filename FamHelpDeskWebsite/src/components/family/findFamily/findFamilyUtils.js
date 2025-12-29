import React from "react";
import { Button, Spin, Alert } from "antd";
import { UserAddOutlined } from "@ant-design/icons";

/**
 * Renders the appropriate actions for a family based on membership status
 * Desktop version - full-sized buttons with text
 */
export const renderFamilyActionsDesktop = (family, actions, isRequesting) => {
  if (actions.isMember) {
    return [
      <Button type="link" onClick={actions.onView}>
        View
      </Button>,
    ];
  }

  return [
    <Button
      type="primary"
      icon={<UserAddOutlined />}
      onClick={actions.onRequestJoin}
      disabled={actions.isDisabled}
      loading={isRequesting}
    >
      {actions.buttonText}
    </Button>,
  ];
};

/**
 * Renders the appropriate actions for a family based on membership status
 * Mobile version - compact buttons with smaller text
 */
export const renderFamilyActionsMobile = (family, actions, isRequesting) => {
  if (actions.isMember) {
    return [
      <Button
        type="link"
        size="small"
        style={{ fontSize: "12px" }}
        onClick={actions.onView}
      >
        View
      </Button>,
    ];
  }

  return [
    <Button
      type="primary"
      icon={<UserAddOutlined />}
      onClick={actions.onRequestJoin}
      disabled={actions.isDisabled}
      loading={isRequesting}
      size="small"
      style={{ fontSize: "11px" }}
    >
      {actions.isPending || actions.hasJustRequested ? "Sent" : "Join"}
    </Button>,
  ];
};

/**
 * Renders loading state
 */
export const renderLoadingState = (isMobile = false) => {
  return (
    <div style={{ padding: isMobile ? "16px" : "50px", textAlign: "center" }}>
      <Spin size={isMobile ? "default" : "large"} />
    </div>
  );
};

/**
 * Renders error state
 */
export const renderErrorState = (error, isMobile = false) => {
  return (
    <div
      style={{
        padding: isMobile ? "16px" : "50px",
        maxWidth: "800px",
        margin: "0 auto",
      }}
    >
      <Alert
        message="Error"
        description={error?.message || "Failed to load families"}
        type="error"
        showIcon
        style={isMobile ? { fontSize: "12px" } : {}}
      />
    </div>
  );
};
