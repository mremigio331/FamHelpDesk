import React from "react";
import { List, Avatar, Space, Typography, Tag, Button, Popconfirm } from "antd";
import {
  UserOutlined,
  ClockCircleOutlined,
  CheckOutlined,
  CloseOutlined,
} from "@ant-design/icons";
import { formatMembershipDate } from "./membershipUtils";

const { Text } = Typography;

const RequestListItem = ({
  request,
  isAdmin,
  isReviewing,
  onApprove,
  onReject,
}) => {
  return (
    <List.Item
      key={request.user_id}
      style={{
        padding: "16px",
        backgroundColor: "#fafafa",
        borderRadius: "8px",
        marginBottom: "12px",
      }}
      actions={
        isAdmin
          ? [
              <Popconfirm
                title="Approve Request"
                description="Are you sure you want to approve this membership request?"
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
                >
                  Approve
                </Button>
              </Popconfirm>,
              <Popconfirm
                title="Reject Request"
                description="Are you sure you want to reject this membership request?"
                onConfirm={() =>
                  onReject(request.user_id, request.user_display_name)
                }
                okText="Yes"
                cancelText="No"
              >
                <Button danger icon={<CloseOutlined />} loading={isReviewing}>
                  Reject
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
            style={{ backgroundColor: "#1890ff" }}
          />
        }
        title={
          <Space>
            <Text strong style={{ fontSize: "16px" }}>
              {request.user_display_name || "Unknown User"}
            </Text>
            <Tag color="orange" icon={<ClockCircleOutlined />}>
              Pending
            </Tag>
          </Space>
        }
        description={
          <Space direction="vertical" size="small">
            <Text type="secondary">{request.user_email}</Text>
            <Text type="secondary" style={{ fontSize: "12px" }}>
              Requested: {formatMembershipDate(request.request_date)}
            </Text>
          </Space>
        }
      />
    </List.Item>
  );
};

export default RequestListItem;
