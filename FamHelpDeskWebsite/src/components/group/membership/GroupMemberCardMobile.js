import React from "react";
import { Card, Avatar, Space, Typography, Tag, Button, Popconfirm } from "antd";
import {
  UserOutlined,
  CheckCircleOutlined,
  CrownOutlined,
  UserDeleteOutlined,
} from "@ant-design/icons";
import { formatMembershipDate } from "./groupMembershipUtils";

const { Text } = Typography;

const GroupMemberCardMobile = ({
  member,
  isAdmin,
  isCurrentUser,
  isUpdatingRole,
  isRemovingMember,
  onToggleAdmin,
  onRemoveMember,
}) => {
  const canManage = isAdmin && !isCurrentUser;

  return (
    <Card
      size="small"
      style={{
        backgroundColor: "#fafafa",
        borderRadius: "8px",
        marginBottom: "8px",
      }}
    >
      <Space direction="vertical" size="small" style={{ width: "100%" }}>
        <Space align="start" style={{ width: "100%" }}>
          <Avatar
            size={40}
            icon={<UserOutlined />}
            style={{ backgroundColor: "#52c41a" }}
          />
          <div style={{ flex: 1 }}>
            <Space wrap size="small">
              <Text strong style={{ fontSize: "14px" }}>
                {member.user_display_name || "Unknown User"}
              </Text>
              {member.is_admin && (
                <Tag
                  color="blue"
                  icon={<CrownOutlined />}
                  style={{ fontSize: "11px" }}
                >
                  Admin
                </Tag>
              )}
              {isCurrentUser && (
                <Tag color="green" style={{ fontSize: "11px" }}>
                  You
                </Tag>
              )}
              <Tag
                color="green"
                icon={<CheckCircleOutlined />}
                style={{ fontSize: "11px" }}
              >
                Active
              </Tag>
            </Space>
            <div>
              <Text type="secondary" style={{ fontSize: "12px" }}>
                {member.user_email}
              </Text>
            </div>
            {member.request_date && (
              <div>
                <Text type="secondary" style={{ fontSize: "11px" }}>
                  Joined: {formatMembershipDate(member.request_date)}
                </Text>
              </div>
            )}
          </div>
        </Space>

        {canManage && (
          <Space size="small" style={{ width: "100%" }}>
            <Button
              size="small"
              type="link"
              icon={<CrownOutlined />}
              onClick={() =>
                onToggleAdmin(
                  member.user_id,
                  member.is_admin,
                  member.user_display_name || member.user_email,
                )
              }
              loading={isUpdatingRole}
              style={{ padding: "0 8px", fontSize: "12px" }}
            >
              {member.is_admin ? "Remove Admin" : "Make Admin"}
            </Button>
            <Popconfirm
              title="Remove Member"
              description={`Remove ${member.user_display_name || member.user_email}?`}
              onConfirm={() =>
                onRemoveMember(
                  member.user_id,
                  member.user_display_name || member.user_email,
                )
              }
              okText="Yes"
              cancelText="No"
            >
              <Button
                size="small"
                type="link"
                danger
                icon={<UserDeleteOutlined />}
                loading={isRemovingMember}
                style={{ padding: "0 8px", fontSize: "12px" }}
              >
                Remove
              </Button>
            </Popconfirm>
          </Space>
        )}
      </Space>
    </Card>
  );
};

export default GroupMemberCardMobile;
