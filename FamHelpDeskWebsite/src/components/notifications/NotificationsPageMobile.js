import React from "react";
import {
  Card,
  Typography,
  Space,
  Button,
  List,
  Tag,
  Spin,
  Empty,
  Alert,
  Divider,
} from "antd";
import {
  CheckOutlined,
  ReloadOutlined,
  BellOutlined,
  CheckCircleOutlined,
} from "@ant-design/icons";
import useNotificationsPage from "./useNotificationsPage";

const { Title, Text } = Typography;

const NotificationsPageMobile = () => {
  const {
    notifications,
    totalCount,
    showAll,
    isNotificationsFetching,
    isNotificationsError,
    notificationsError,
    notificationsRefetch,
    handleToggleShowAll,
    handleAcknowledge,
    isAcknowledging,
    isAcknowledgeError,
    acknowledgeError,
    handleAcknowledgeAll,
    isAcknowledgingAll,
    isAcknowledgeAllError,
    acknowledgeAllError,
    handleLoadMore,
    hasNextPage,
    isFetchingNextPage,
  } = useNotificationsPage();

  const renderNotificationItem = (notification) => {
    const isUnread = !notification.viewed;

    return (
      <List.Item
        key={notification.notification_id}
        style={{
          backgroundColor: isUnread ? "#f0f5ff" : "white",
          padding: "12px",
          borderRadius: "6px",
          marginBottom: "8px",
        }}
      >
        <Space direction="vertical" size="small" style={{ width: "100%" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
            <BellOutlined style={{ fontSize: "18px", color: "#1890ff" }} />
            <Text strong style={{ fontSize: "14px" }}>
              {notification.title || "Notification"}
            </Text>
            {isUnread && <Tag color="blue">New</Tag>}
          </div>
          <Text style={{ fontSize: "13px" }}>{notification.message}</Text>
          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
            }}
          >
            <Text type="secondary" style={{ fontSize: "11px" }}>
              {new Date(notification.timestamp).toLocaleString()}
            </Text>
            {isUnread && (
              <Button
                type="link"
                size="small"
                icon={<CheckOutlined />}
                onClick={() => handleAcknowledge(notification.notification_id)}
                loading={isAcknowledging}
                style={{ fontSize: "12px", padding: "0" }}
              >
                Mark Read
              </Button>
            )}
          </div>
        </Space>
      </List.Item>
    );
  };

  return (
    <div style={{ padding: "12px" }}>
      <Space
        direction="vertical"
        size="middle"
        style={{ width: "100%", minHeight: "400px" }}
      >
        {/* Header */}
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            marginBottom: "8px",
          }}
        >
          <Title level={4} style={{ margin: 0 }}>
            <BellOutlined /> Notifications
          </Title>
          <Button
            icon={<ReloadOutlined />}
            onClick={() => notificationsRefetch()}
            loading={isNotificationsFetching}
            size="small"
          />
        </div>

        {/* Filter Toggle */}
        <Card size="small">
          <Space direction="vertical" size="small" style={{ width: "100%" }}>
            <div style={{ display: "flex", gap: "8px" }}>
              <Button
                type={!showAll ? "primary" : "default"}
                onClick={handleToggleShowAll}
                size="small"
                block
              >
                Unread Only
              </Button>
              <Button
                type={showAll ? "primary" : "default"}
                onClick={handleToggleShowAll}
                size="small"
                block
              >
                Show All
              </Button>
            </div>
            {!showAll && notifications.length > 0 && (
              <Button
                type="primary"
                icon={<CheckCircleOutlined />}
                onClick={handleAcknowledgeAll}
                loading={isAcknowledgingAll}
                size="small"
                block
              >
                Mark All as Read
              </Button>
            )}
          </Space>
        </Card>

        {/* Error States */}
        {isNotificationsError && (
          <Alert
            message="Error"
            description={notificationsError?.message || "Failed to load"}
            type="error"
            showIcon
            closable
            style={{ fontSize: "12px" }}
          />
        )}
        {isAcknowledgeError && (
          <Alert
            message="Error"
            description={acknowledgeError?.message || "Failed to acknowledge"}
            type="error"
            showIcon
            closable
            style={{ fontSize: "12px" }}
          />
        )}
        {isAcknowledgeAllError && (
          <Alert
            message="Error"
            description={
              acknowledgeAllError?.message || "Failed to acknowledge all"
            }
            type="error"
            showIcon
            closable
            style={{ fontSize: "12px" }}
          />
        )}

        {/* Notifications List */}
        {isNotificationsFetching && notifications.length === 0 ? (
          <div style={{ textAlign: "center", padding: "40px" }}>
            <Spin size="large" />
          </div>
        ) : notifications.length === 0 ? (
          <Empty
            image={Empty.PRESENTED_IMAGE_SIMPLE}
            description={
              showAll ? "No notifications yet" : "No unread notifications"
            }
            style={{ padding: "40px 0" }}
          />
        ) : (
          <>
            <List
              dataSource={notifications}
              renderItem={renderNotificationItem}
              style={{ backgroundColor: "#fafafa", padding: "8px" }}
            />

            {/* Load More */}
            {hasNextPage && (
              <div style={{ textAlign: "center", marginTop: "8px" }}>
                <Button
                  onClick={handleLoadMore}
                  loading={isFetchingNextPage}
                  block
                >
                  Load More
                </Button>
              </div>
            )}

            {/* Count */}
            <Text
              type="secondary"
              style={{
                textAlign: "center",
                display: "block",
                fontSize: "12px",
              }}
            >
              Showing {notifications.length} notification(s)
            </Text>
          </>
        )}
      </Space>
    </div>
  );
};

export default NotificationsPageMobile;
