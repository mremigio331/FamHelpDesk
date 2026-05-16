import React from "react";
import { Card, Tag, Typography, Space } from "antd";
import {
  UserOutlined,
  DollarOutlined,
  ClockCircleOutlined,
} from "@ant-design/icons";

const { Text, Title } = Typography;

const statusColors = {
  OPEN: "blue",
  CLAIMED: "orange",
  COMPLETED: "purple",
  CONFIRMED: "green",
  CANCELLED: "red",
};

const GrabRequestCard = ({ request, onClick, getDisplayName }) => {
  const createdDate = request.created_at
    ? new Date(request.created_at * 1000).toLocaleDateString()
    : "";

  return (
    <Card
      hoverable
      onClick={onClick}
      size="small"
      style={{ cursor: "pointer" }}
    >
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "flex-start",
        }}
      >
        <div style={{ flex: 1 }}>
          <Space align="center" style={{ marginBottom: "4px" }}>
            <Title level={5} style={{ margin: 0 }}>
              {request.title}
            </Title>
            <Tag color={statusColors[request.status] || "default"}>
              {request.status}
            </Tag>
          </Space>

          <Text type="secondary" style={{ display: "block", marginBottom: "8px" }}>
            <UserOutlined /> {getDisplayName ? getDisplayName(request.requestor_id) : (typeof request.requestor_id === "object" ? (request.requestor_id.name || request.requestor_id.id) : request.requestor_id)}
          </Text>

          <Space size="middle" wrap>
            <Text type="secondary">
              <DollarOutlined /> {request.embolec_cost} Embolecs
            </Text>
            {request.claimer_id && (
              <Text type="secondary">
                Claimer: {getDisplayName ? getDisplayName(request.claimer_id) : (typeof request.claimer_id === "object" ? (request.claimer_id.name || request.claimer_id.id) : request.claimer_id)}
              </Text>
            )}
            <Text type="secondary">
              <ClockCircleOutlined /> {createdDate}
            </Text>
          </Space>

          {request.items && request.items.length > 0 && (
            <div style={{ marginTop: "8px" }}>
              <Text type="secondary">
                Items: {request.items.map((item) => item.name).join(", ")}
              </Text>
            </div>
          )}
        </div>
      </div>
    </Card>
  );
};

export default GrabRequestCard;
