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
  Tabs,
} from "antd";
import {
  UserOutlined,
  ClockCircleOutlined,
  CheckCircleOutlined,
} from "@ant-design/icons";
import useGetFamilyMembershipRequests from "../../hooks/membership/useGetFamilyMembershipRequests";
import useGetFamilyMembers from "../../hooks/membership/useGetFamilyMembers";

const { Title, Text } = Typography;

const MembersDesktop = ({ familyId }) => {
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

  return (
    <Card>
      <Tabs
        activeKey={activeTab}
        onChange={setActiveTab}
        items={[
          {
            key: "members",
            label: (
              <span>
                <UserOutlined /> Members {memberCount > 0 && `(${memberCount})`}
              </span>
            ),
            children: (
              <div>
                {isFetchingMembers ? (
                  <div style={{ textAlign: "center", padding: "40px" }}>
                    <Spin size="large" />
                  </div>
                ) : isMembersError ? (
                  <Alert
                    message="Error Loading Members"
                    description={membersError?.message || "An error occurred"}
                    type="error"
                    showIcon
                  />
                ) : members.length === 0 ? (
                  <Empty
                    image={Empty.PRESENTED_IMAGE_SIMPLE}
                    description="No members found"
                    style={{ padding: "40px 0" }}
                  />
                ) : (
                  <List
                    itemLayout="horizontal"
                    dataSource={members}
                    renderItem={(member) => (
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
                                <Text
                                  type="secondary"
                                  style={{ fontSize: "12px" }}
                                >
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
                )}
              </div>
            ),
          },
          {
            key: "requests",
            label: (
              <span>
                <ClockCircleOutlined /> Requests{" "}
                {requestCount > 0 && `(${requestCount})`}
              </span>
            ),
            children: (
              <div>
                {isFetchingRequests ? (
                  <div style={{ textAlign: "center", padding: "40px" }}>
                    <Spin size="large" />
                  </div>
                ) : isRequestsError ? (
                  <Alert
                    message="Error Loading Requests"
                    description={requestsError?.message || "An error occurred"}
                    type="error"
                    showIcon
                  />
                ) : requests.length === 0 ? (
                  <Empty
                    image={Empty.PRESENTED_IMAGE_SIMPLE}
                    description="No pending membership requests"
                    style={{ padding: "40px 0" }}
                  />
                ) : (
                  <List
                    itemLayout="horizontal"
                    dataSource={requests}
                    renderItem={(request) => (
                      <List.Item
                        key={request.user_id}
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
                              style={{ backgroundColor: "#1890ff" }}
                            />
                          }
                          title={
                            <Space>
                              <Text strong style={{ fontSize: "16px" }}>
                                {request.user_display_name || "Unknown User"}
                              </Text>
                              <Tag
                                color="orange"
                                icon={<ClockCircleOutlined />}
                              >
                                Pending
                              </Tag>
                            </Space>
                          }
                          description={
                            <Space direction="vertical" size="small">
                              <Text type="secondary">{request.user_email}</Text>
                              <Text
                                type="secondary"
                                style={{ fontSize: "12px" }}
                              >
                                Requested:{" "}
                                {new Date(
                                  request.request_date * 1000,
                                ).toLocaleDateString()}
                              </Text>
                            </Space>
                          }
                        />
                      </List.Item>
                    )}
                  />
                )}
              </div>
            ),
          },
        ]}
      />
    </Card>
  );
};

export default MembersDesktop;
