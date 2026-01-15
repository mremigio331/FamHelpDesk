import React from "react";
import { Card, Avatar, Space, Typography, Tag, Button, Popconfirm } from "antd";
import {
  UserOutlined,
  ClockCircleOutlined,
  CheckOutlined,
  CloseOutlined,
} from "@ant-design/icons";
import { formatMembershipDate } from "./groupMembershipUtils";

const { Text } = Typography;

const GroupMembershipRequestCardMobile = ({
  request,
  isAdmin,
  isReviewing,
  onApprove,
  onReject,
}) => {
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
            style={{ backgroundColor: "#1890ff" }}
          />
          <div style={{ flex: 1 }}>
            <Space wrap size="small">
              <Text strong style={{ fontSize: "14px" }}>
                {request.user_display_name || "Unknown User"}
              </Text>
              <Tag color="orange" icon={<ClockCircleOutlined />} style={{ fontSize: "11px" }}>
                Pending
              </Tag>
            </Space>
            <div>
              <Text type="secondary" style={{ fontSize: "12px" }}>
                {request.user_email}
              </Text>
            </div>
            <div>
              <Text type="secondary" style={{ fontSize: "11px" }}>
                Requested: {formatMembershipDate(request.request_date)}
              </Text>
            </div>
          </div>
        </Space>

        {isAdmin && (
          <Space size="small" style={{ width: "100%" }}>
            <Popconfirm
              title="Approve Request"
              description={`Approve ${request.user_display_name || request.user_email}?`}
              onConfirm={() =>
                onApprove(
                  request.user_id,
                  request.user_display_name || request.user_email,
                )
              }
              okText="Yes"
              cancelText="No"
            >
              <Button
                size="small"
                type="primary"
                icon={<CheckOutlined />}
                loading={isReviewing}
                style={{ fontSize: "12px", flex: 1 }}
              >
                Approve
              </Button>
            </Popconfirm>
            <Popconfirm
              title="Reject Request"
              description={`Reject ${request.user_display_name || request.user_email}?`}
              onConfirm={() =>
                onReject(
                  request.user_id,
                  request.user_display_name || request.user_email,
                )
              }
              okText="Yes"
              cancelText="No"
            >
              <Button
                size="small"
                danger
                icon={<CloseOutlined />}
                loading={isReviewing}
                style={{ fontSize: "12px", flex: 1 }}
              >
                Reject
              </Button>
            </Popconfirm>
          </Space>
        )}
      </Space>
    </Card>
  );
};

export default GroupMembershipRequestCardMobile;
