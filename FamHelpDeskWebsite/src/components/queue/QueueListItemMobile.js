import React from "react";
import { Card, Space, Button, Row, Col } from "antd";
import { InboxOutlined, FileTextOutlined } from "@ant-design/icons";
import { Typography } from "antd";
import { useQueueListItem } from "./useQueueListItem";

const { Text } = Typography;

const QueueListItemMobile = (props) => {
  const {
    queue,
    actions = null,
    onClick = null,
    showCreatedDate = true,
    showStats = true,
  } = props;
  const { defaultActions } = useQueueListItem({
    queue,
    actions,
  });

  return (
    <Card
      size="small"
      style={{
        marginBottom: "12px",
        borderRadius: "12px",
        boxShadow: "0 2px 8px rgba(0, 0, 0, 0.08)",
        cursor: onClick ? "pointer" : "default",
      }}
      onClick={onClick}
      bodyStyle={{ padding: "16px" }}
    >
      <Space direction="vertical" size="small" style={{ width: "100%" }}>
        {/* Header with icon and title */}
        <Space size={8} align="start" style={{ width: "100%" }}>
          <InboxOutlined
            style={{
              fontSize: "28px",
              color: "#52c41a",
              padding: "10px",
              backgroundColor: "#f6ffed",
              borderRadius: "10px",
            }}
          />
          <div style={{ flex: 1 }}>
            <Text
              strong
              style={{
                fontSize: "16px",
                lineHeight: "1.4",
                display: "block",
              }}
            >
              {queue.queue_name}
            </Text>
            {queue.queue_description && (
              <Text
                type="secondary"
                style={{
                  fontSize: "13px",
                  display: "block",
                  marginTop: "4px",
                  lineHeight: "1.5",
                }}
              >
                {queue.queue_description}
              </Text>
            )}
          </div>
        </Space>

        {/* Stats */}
        {showStats && (
          <Row gutter={16} style={{ marginTop: "8px" }}>
            <Col span={12}>
              <Space size={8}>
                <FileTextOutlined
                  style={{ fontSize: "16px", color: "#1890ff" }}
                />
                <div>
                  <Text
                    type="secondary"
                    style={{ fontSize: "11px", display: "block" }}
                  >
                    Open
                  </Text>
                  <Text style={{ fontSize: "14px", fontWeight: "500" }}>
                    {queue.open_ticket_count || 0}
                  </Text>
                </div>
              </Space>
            </Col>
            <Col span={12}>
              <Space size={8}>
                <FileTextOutlined
                  style={{ fontSize: "16px", color: "#52c41a" }}
                />
                <div>
                  <Text
                    type="secondary"
                    style={{ fontSize: "11px", display: "block" }}
                  >
                    Total
                  </Text>
                  <Text style={{ fontSize: "14px", fontWeight: "500" }}>
                    {queue.total_ticket_count || 0}
                  </Text>
                </div>
              </Space>
            </Col>
          </Row>
        )}

        {/* Created date */}
        {showCreatedDate && queue.creation_date && (
          <Text
            type="secondary"
            style={{ fontSize: "12px", display: "block", marginTop: "4px" }}
          >
            Created: {new Date(queue.creation_date * 1000).toLocaleDateString()}
          </Text>
        )}

        {/* Actions */}
        {(actions || defaultActions.length > 0) && (
          <Space size={8} style={{ marginTop: "8px", width: "100%" }} wrap>
            {actions
              ? actions
              : defaultActions.map((action) => (
                  <Button
                    key={action.key}
                    type={action.key === "view" ? "primary" : "default"}
                    size="middle"
                    style={{ minHeight: "40px", flex: 1 }}
                    onClick={(e) => {
                      e.stopPropagation();
                      action.onClick();
                    }}
                  >
                    {action.label}
                  </Button>
                ))}
          </Space>
        )}
      </Space>
    </Card>
  );
};

export default QueueListItemMobile;
