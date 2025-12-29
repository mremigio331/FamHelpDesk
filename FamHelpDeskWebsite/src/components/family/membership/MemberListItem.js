import React from "react";
import { List, Avatar, Space, Typography, Tag } from "antd";
import { UserOutlined, CheckCircleOutlined } from "@ant-design/icons";
import { formatMembershipDate } from "./membershipUtils";

const { Text } = Typography;

const MemberListItem = ({ member }) => {
  return (
    <List.Item
      key={member.user_id}
      style={{
        padding: "16px",
        backgroundColor: "#fafafa",
        borderRadius: "8px",
        marginBottom: "12px",
      }}
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
            {member.is_admin && <Tag color="gold">Admin</Tag>}
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

export default MemberListItem;
