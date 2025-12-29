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

const NotificationsPageDesktop = () => {
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
          padding: "16px",
          borderRadius: "8px",
          marginBottom: "8px",
        }}
        actions={
          isUnread
            ? [
                <Button
                  type="link"
                  icon={<CheckOutlined />}
                  onClick={() =>
                    handleAcknowledge(notification.notification_id)
                  }
                  loading={isAcknowledging}
                >
                  Mark as Read
                </Button>,
              ]
            : []
        }
      >
        <List.Item.Meta
          avatar={
            <BellOutlined style={{ fontSize: "24px", color: "#1890ff" }} />
          }
          title={
            <Space>
              <Text strong>{notification.title || "Notification"}</Text>
              {isUnread && <Tag color="blue">New</Tag>}
            </Space>
          }
          description={
            <Space direction="vertical" size="small" style={{ width: "100%" }}>
              <Text>{notification.message}</Text>
              <Text type="secondary" style={{ fontSize: "12px" }}>
                {new Date(notification.timestamp).toLocaleString()}
              </Text>
            </Space>
          }
        />
      </List.Item>
    );
  };

  return (
    <div style={{ padding: "24px", maxWidth: "900px", margin: "0 auto" }}>
      <Card>
        <Space
          direction="vertical"
          size="large"
          style={{ width: "100%", minHeight: "400px" }}
        >
          {/* Header */}
          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
            }}
          >
            <Title level={2}>
              <BellOutlined /> Notifications
            </Title>
            <Space>
              <Button
                icon={<ReloadOutlined />}
                onClick={() => notificationsRefetch()}
                loading={isNotificationsFetching}
              >
                Refresh
              </Button>
            </Space>
          </div>

          {/* Filter Toggle */}
          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
            }}
          >
            <Space>
              <Button
                type={!showAll ? "primary" : "default"}
                onClick={handleToggleShowAll}
              >
                Unread Only
              </Button>
              <Button
                type={showAll ? "primary" : "default"}
                onClick={handleToggleShowAll}
              >
                Show All
              </Button>
            </Space>
            {!showAll && notifications.length > 0 && (
              <Button
                type="primary"
                icon={<CheckCircleOutlined />}
                onClick={handleAcknowledgeAll}
                loading={isAcknowledgingAll}
              >
                Mark All as Read
              </Button>
            )}
          </div>

          <Divider />

          {/* Error States */}
          {isNotificationsError && (
            <Alert
              message="Error Loading Notifications"
              description={notificationsError?.message || "An error occurred"}
              type="error"
              showIcon
            />
          )}
          {isAcknowledgeError && (
            <Alert
              message="Error Acknowledging Notification"
              description={acknowledgeError?.message || "An error occurred"}
              type="error"
              showIcon
              closable
            />
          )}
          {isAcknowledgeAllError && (
            <Alert
              message="Error Acknowledging All Notifications"
              description={acknowledgeAllError?.message || "An error occurred"}
              type="error"
              showIcon
              closable
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
                <div style={{ textAlign: "center", marginTop: "16px" }}>
                  <Button
                    onClick={handleLoadMore}
                    loading={isFetchingNextPage}
                    size="large"
                  >
                    Load More
                  </Button>
                </div>
              )}

              {/* Count */}
              <Text
                type="secondary"
                style={{ textAlign: "center", display: "block" }}
              >
                Showing {notifications.length} notification(s)
              </Text>
            </>
          )}
        </Space>
      </Card>
    </div>
  );
};

export default NotificationsPageDesktop;
