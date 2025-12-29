import React from "react";
import { Card, Avatar, Space, Typography, Tag } from "antd";
import { UserOutlined, CheckCircleOutlined } from "@ant-design/icons";
import { formatMembershipDate } from "./membershipUtils";

const { Text } = Typography;

const MemberCardMobile = ({ member }) => {
  return (
    <Card
      key={member.user_id}
      size="small"
      style={{
        backgroundColor: "#fafafa",
        borderRadius: "6px",
        marginBottom: "8px",
      }}
    >
      <Space size="small">
        <Avatar
          size={32}
          icon={<UserOutlined />}
          style={{ backgroundColor: "#52c41a" }}
        />
        <div>
          <Space size="small" wrap>
            <Text strong style={{ fontSize: "13px" }}>
              {member.user_display_name || "Unknown User"}
            </Text>
            {member.is_admin && (
              <Tag color="gold" style={{ fontSize: "10px" }}>
                Admin
              </Tag>
            )}
            <Tag
              color="green"
              icon={<CheckCircleOutlined />}
              style={{ fontSize: "10px" }}
            >
              Active
            </Tag>
          </Space>
          <div>
            <Text type="secondary" style={{ fontSize: "11px" }}>
              {member.user_email}
            </Text>
          </div>
          {member.request_date && (
            <Text type="secondary" style={{ fontSize: "10px" }}>
              Joined: {formatMembershipDate(member.request_date)}
            </Text>
          )}
        </div>
      </Space>
    </Card>
  );
};

export default MemberCardMobile;
