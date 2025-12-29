import React, { useState } from "react";
import {
  Card,
  List,
  Typography,
  Tag,
  Space,
  Avatar,
  Empty,
  Spin,
  Alert,
  Segmented,
} from "antd";
import {
  UserOutlined,
  ClockCircleOutlined,
  CheckCircleOutlined,
} from "@ant-design/icons";
import useGetFamilyMembershipRequests from "../../hooks/membership/useGetFamilyMembershipRequests";
import useGetFamilyMembers from "../../hooks/membership/useGetFamilyMembers";

const { Title, Text } = Typography;

const MembersMobile = ({ familyId }) => {
  const [activeTab, setActiveTab] = useState("members");

  const {
    requests,
    requestCount,
    isFetchingRequests,
    isRequestsError,
    requestsError,
  } = useGetFamilyMembershipRequests(familyId);

  const {
    members,
    memberCount,
    isFetchingMembers,
    isMembersError,
    membersError,
  } = useGetFamilyMembers(familyId);

  const renderContent = () => {
    if (activeTab === "members") {
      if (isFetchingMembers) {
        return (
          <div style={{ textAlign: "center", padding: "40px 20px" }}>
            <Spin size="large" />
          </div>
        );
      }

      if (isMembersError) {
        return (
          <Alert
            message="Error"
            description={membersError?.message || "Failed to load members"}
            type="error"
            showIcon
            style={{ fontSize: "12px" }}
          />
        );
      }

      if (members.length === 0) {
        return (
          <Empty
            image={Empty.PRESENTED_IMAGE_SIMPLE}
            description="No members found"
            style={{ padding: "20px 0", fontSize: "12px" }}
          />
        );
      }

      return (
        <List
          itemLayout="horizontal"
          dataSource={members}
          renderItem={(member) => (
            <List.Item
              key={member.user_id}
              style={{
                padding: "12px",
                backgroundColor: "#fafafa",
                borderRadius: "6px",
                marginBottom: "8px",
              }}
            >
              <List.Item.Meta
                avatar={
                  <Avatar
                    size={40}
                    icon={<UserOutlined />}
                    style={{ backgroundColor: "#52c41a" }}
                  />
                }
                title={
                  <Space size="small" wrap>
                    <Text strong style={{ fontSize: "14px" }}>
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
                }
                description={
                  <Space direction="vertical" size={2}>
                    <Text type="secondary" style={{ fontSize: "12px" }}>
                      {member.user_email}
                    </Text>
                    {member.request_date && (
                      <Text type="secondary" style={{ fontSize: "11px" }}>
                        Joined:{" "}
                        {new Date(
                          member.request_date * 1000,
                        ).toLocaleDateString()}
                      </Text>
                    )}
                  </Space>
                }
              />
            </List.Item>
          )}
        />
      );
    }

    // Requests tab
    if (isFetchingRequests) {
      return (
        <div style={{ textAlign: "center", padding: "40px 20px" }}>
          <Spin size="large" />
        </div>
      );
    }

    if (isRequestsError) {
      return (
        <Alert
          message="Error"
          description={requestsError?.message || "Failed to load requests"}
          type="error"
          showIcon
          style={{ fontSize: "12px" }}
        />
      );
    }

    if (requests.length === 0) {
      return (
        <Empty
          image={Empty.PRESENTED_IMAGE_SIMPLE}
          description="No pending requests"
          style={{ padding: "20px 0", fontSize: "12px" }}
        />
      );
    }

    return (
      <List
        itemLayout="horizontal"
        dataSource={requests}
        renderItem={(request) => (
          <List.Item
            key={request.user_id}
            style={{
              padding: "12px",
              backgroundColor: "#fafafa",
              borderRadius: "6px",
              marginBottom: "8px",
            }}
          >
            <List.Item.Meta
              avatar={
                <Avatar
                  size={40}
                  icon={<UserOutlined />}
                  style={{ backgroundColor: "#1890ff" }}
                />
              }
              title={
                <Space size="small">
                  <Text strong style={{ fontSize: "14px" }}>
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
              }
              description={
                <Space direction="vertical" size={2}>
                  <Text type="secondary" style={{ fontSize: "12px" }}>
                    {request.user_email}
                  </Text>
                  <Text type="secondary" style={{ fontSize: "11px" }}>
                    Requested:{" "}
                    {new Date(request.request_date * 1000).toLocaleDateString()}
                  </Text>
                </Space>
              }
            />
          </List.Item>
        )}
      />
    );
  };

  return (
    <Space direction="vertical" size="middle" style={{ width: "100%" }}>
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          gap: "12px",
        }}
      >
        <Title level={5} style={{ margin: 0 }}>
          <UserOutlined /> Family Members
        </Title>
        <Segmented
          value={activeTab}
          onChange={setActiveTab}
          options={[
            {
              label: `Members (${memberCount})`,
              value: "members",
            },
            {
              label: `Requests (${requestCount})`,
              value: "requests",
            },
          ]}
          block
          style={{ fontSize: "12px" }}
        />
      </div>

      {renderContent()}
    </Space>
  );
};

export default MembersMobile;
