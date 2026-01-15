import React from "react";
import {
  List,
  Avatar,
  Space,
  Typography,
  Tag,
  Button,
  Popconfirm,
} from "antd";
import {
  UserOutlined,
  CheckCircleOutlined,
  CrownOutlined,
  UserDeleteOutlined,
} from "@ant-design/icons";
import { formatMembershipDate } from "./groupMembershipUtils";

const { Text } = Typography;

const GroupMemberListItem = ({
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
    <List.Item
      key={member.user_id}
      style={{
        padding: "16px",
        backgroundColor: "#fafafa",
        borderRadius: "8px",
        marginBottom: "12px",
      }}
      actions={
        canManage
          ? [
              <Button
                key="toggle-admin"
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
              >
                {member.is_admin ? "Remove Admin" : "Make Admin"}
              </Button>,
              <Popconfirm
                key="remove"
                title="Remove Member"
                description={`Are you sure you want to remove ${member.user_display_name || member.user_email} from this group?`}
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
                  type="link"
                  danger
                  icon={<UserDeleteOutlined />}
                  loading={isRemovingMember}
                >
                  Remove
                </Button>
              </Popconfirm>,
            ]
          : []
      }
    >
      <List.Item.Meta
        avatar={
          <Avatar
            size={48}
            icon={<UserOutlined />}
            style={{ backgroundColor: "#52c41a" }}
          />
        }
        title={
          <Space>
            <Text strong style={{ fontSize: "16px" }}>
              {member.user_display_name || "Unknown User"}
            </Text>
            {member.is_admin && (
              <Tag color="blue" icon={<CrownOutlined />}>
                Admin
              </Tag>
            )}
            {isCurrentUser && <Tag color="green">You</Tag>}
            <Tag color="green" icon={<CheckCircleOutlined />}>
              Active
            </Tag>
          </Space>
        }
        description={
          <Space direction="vertical" size="small">
            <Text type="secondary">{member.user_email}</Text>
            {member.request_date && (
              <Text type="secondary" style={{ fontSize: "12px" }}>
                Joined: {formatMembershipDate(member.request_date)}
              </Text>
            )}
          </Space>
        }
      />
    </List.Item>
  );
};

export default GroupMemberListItem;
