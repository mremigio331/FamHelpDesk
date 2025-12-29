import React from "react";
import { Card, Avatar, Space, Typography, Tag, Button, Popconfirm } from "antd";
import {
  UserOutlined,
  ClockCircleOutlined,
  CheckOutlined,
  CloseOutlined,
} from "@ant-design/icons";
import { formatMembershipDate } from "./membershipUtils";

const { Text } = Typography;

const RequestCardMobile = ({
  request,
  isAdmin,
  isReviewing,
  onApprove,
  onReject,
}) => {
  return (
    <Card
      key={request.user_id}
      size="small"
      style={{
        backgroundColor: "#fafafa",
        borderRadius: "6px",
        marginBottom: "8px",
      }}
    >
      <Space direction="vertical" size="small" style={{ width: "100%" }}>
        <Space size="small">
          <Avatar
            size={32}
            icon={<UserOutlined />}
            style={{ backgroundColor: "#1890ff" }}
          />
          <div>
            <Space size="small" wrap>
              <Text strong style={{ fontSize: "13px" }}>
                {request.user_display_name || "Unknown User"}
              </Text>
              <Tag
                color="orange"
                icon={<ClockCircleOutlined />}
                style={{ fontSize: "10px" }}
              >
                Pending
              </Tag>
            </Space>
            <div>
              <Text type="secondary" style={{ fontSize: "11px" }}>
                {request.user_email}
              </Text>
            </div>
            <Text type="secondary" style={{ fontSize: "10px" }}>
              Requested: {formatMembershipDate(request.request_date)}
            </Text>
          </div>
        </Space>

        {isAdmin && (
          <Space size="small" style={{ width: "100%" }}>
            <Popconfirm
              title="Approve?"
              description="Approve this membership request?"
              onConfirm={() =>
                onApprove(request.user_id, request.user_display_name)
              }
              okText="Yes"
              cancelText="No"
            >
              <Button
                type="primary"
                icon={<CheckOutlined />}
                loading={isReviewing}
                size="small"
                block
              >
                Approve
              </Button>
            </Popconfirm>
            <Popconfirm
              title="Reject?"
              description="Reject this membership request?"
              onConfirm={() =>
                onReject(request.user_id, request.user_display_name)
              }
              okText="Yes"
              cancelText="No"
            >
              <Button
                danger
                icon={<CloseOutlined />}
                loading={isReviewing}
                size="small"
                block
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

export default RequestCardMobile;
