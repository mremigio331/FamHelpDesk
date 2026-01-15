import React from "react";
import { List, Tag, Space, Button, Row, Col, Card } from "antd";
import { TeamOutlined, UserOutlined, InboxOutlined } from "@ant-design/icons";
import { Typography } from "antd";
import { useGroupListItem } from "./useGroupListItem";

const { Text } = Typography;

const GroupListItemMobile = (props) => {
  const {
    group,
    membership = null,
    actions = null,
    onClick = null,
    showCreatedDate = true,
    showStats = true,
    showMembershipStatus = true,
  } = props;
  const { statusTag, defaultActions } = useGroupListItem({
    group,
    membership,
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
          <TeamOutlined
            style={{
              fontSize: "28px",
              color: "#1890ff",
              padding: "10px",
              backgroundColor: "#e6f7ff",
              borderRadius: "10px",
            }}
          />
          <div style={{ flex: 1 }}>
            <Space size={6} wrap>
              <Text
                strong
                style={{
                  fontSize: "16px",
                  lineHeight: "1.4",
                }}
              >
                {group.group_name}
              </Text>
              {showMembershipStatus && statusTag && (
                <Tag
                  color={statusTag.statusColor}
                  style={{ fontSize: "11px", margin: 0 }}
                >
                  {statusTag.statusText}
                </Tag>
              )}
            </Space>
            {group.group_description && (
              <Text
                type="secondary"
                style={{
                  fontSize: "13px",
                  display: "block",
                  marginTop: "4px",
                  lineHeight: "1.5",
                }}
              >
                {group.group_description}
              </Text>
            )}
          </div>
        </Space>

        {/* Stats */}
        {showStats && (
          <Row gutter={16} style={{ marginTop: "8px" }}>
            <Col span={12}>
              <Space size={8}>
                <UserOutlined style={{ fontSize: "16px", color: "#1890ff" }} />
                <Text style={{ fontSize: "14px", fontWeight: "500" }}>
                  {group.member_count || 0} members
                </Text>
              </Space>
            </Col>
            <Col span={12}>
              <Space size={8}>
                <InboxOutlined style={{ fontSize: "16px", color: "#52c41a" }} />
                <Text style={{ fontSize: "14px", fontWeight: "500" }}>
                  {group.queue_count || 0} queues
                </Text>
              </Space>
            </Col>
          </Row>
        )}

        {/* Created date */}
        {showCreatedDate && group.creation_date && (
          <Text
            type="secondary"
            style={{ fontSize: "12px", display: "block", marginTop: "4px" }}
          >
            Created: {new Date(group.creation_date * 1000).toLocaleDateString()}
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

export default GroupListItemMobile;
