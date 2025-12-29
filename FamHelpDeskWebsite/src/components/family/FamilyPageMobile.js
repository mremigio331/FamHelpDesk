import React from "react";
import { useParams, useNavigate } from "react-router-dom";
import { Card, Typography, Button, Space, Spin, Alert } from "antd";
import {
  FileTextOutlined,
  TeamOutlined,
  InboxOutlined,
  UserOutlined,
  PlusCircleOutlined,
  ArrowLeftOutlined,
} from "@ant-design/icons";
import { useMyFamilies } from "../../provider/MyFamiliesProvider";
import useFamilyPage from "./useFamilyPage";
import MembersMobile from "./MembersMobile";

const { Title, Text } = Typography;

const FamilyPageMobile = () => {
  const { familyId } = useParams();
  const navigate = useNavigate();
  const { myFamilies, isMyFamiliesFetching, isMyFamiliesError } =
    useMyFamilies();
  const { activeSection, handleSectionChange } = useFamilyPage();

  if (isMyFamiliesFetching) {
    return (
      <div style={{ padding: "50px", textAlign: "center" }}>
        <Spin size="large" />
      </div>
    );
  }

  if (isMyFamiliesError) {
    return (
      <div style={{ padding: "20px" }}>
        <Alert
          message="Error"
          description="Failed to load family information"
          type="error"
          showIcon
        />
      </div>
    );
  }

  const familyData = myFamilies[familyId];

  if (!familyData) {
    return (
      <div style={{ padding: "20px" }}>
        <Alert
          message="Family Not Found"
          description="You do not have access to this family or it does not exist."
          type="warning"
          showIcon
          action={
            <Button type="primary" onClick={() => navigate("/")} block>
              Go Home
            </Button>
          }
        />
      </div>
    );
  }

  const { family, membership } = familyData;
  const isMember = membership?.status === "MEMBER";

  // Show restricted view for non-members
  if (!isMember) {
    return (
      <div style={{ padding: "16px" }}>
        <div style={{ marginBottom: "16px" }}>
          <Button
            type="link"
            icon={<ArrowLeftOutlined />}
            onClick={() => navigate("/")}
            style={{ paddingLeft: 0, fontSize: "14px" }}
          >
            Back to Home
          </Button>
        </div>

        <Card>
          <Alert
            message="Membership Pending"
            description="Your membership request is pending approval. You will gain access once approved."
            type="info"
            showIcon
            style={{ marginBottom: "20px", fontSize: "12px" }}
          />

          <Space direction="vertical" size="middle" style={{ width: "100%" }}>
            <div>
              <Title level={4} style={{ marginBottom: "8px" }}>
                {family.family_name}
              </Title>
              {family.family_description && (
                <Text type="secondary" style={{ fontSize: "14px" }}>
                  {family.family_description}
                </Text>
              )}
            </div>
          </Space>
        </Card>
      </div>
    );
  }

  const renderContent = () => {
    switch (activeSection) {
      case "tickets":
        return (
          <div style={{ textAlign: "center", padding: "40px 20px" }}>
            <FileTextOutlined style={{ fontSize: "48px", color: "#bfbfbf" }} />
            <Title level={4} style={{ marginTop: "12px", color: "#595959" }}>
              Tickets
            </Title>
            <Text type="secondary">Coming Soon</Text>
          </div>
        );
      case "groups":
        return (
          <div style={{ textAlign: "center", padding: "40px 20px" }}>
            <TeamOutlined style={{ fontSize: "48px", color: "#bfbfbf" }} />
            <Title level={4} style={{ marginTop: "12px", color: "#595959" }}>
              Groups
            </Title>
            <Text type="secondary">Coming Soon</Text>
          </div>
        );
      case "queues":
        return (
          <div style={{ textAlign: "center", padding: "40px 20px" }}>
            <InboxOutlined style={{ fontSize: "48px", color: "#bfbfbf" }} />
            <Title level={4} style={{ marginTop: "12px", color: "#595959" }}>
              Queues
            </Title>
            <Text type="secondary">Coming Soon</Text>
          </div>
        );
      case "members":
        return <MembersMobile familyId={familyId} />;
      case "create":
        return (
          <div style={{ textAlign: "center", padding: "40px 20px" }}>
            <PlusCircleOutlined style={{ fontSize: "48px", color: "#bfbbf" }} />
            <Title level={4} style={{ marginTop: "12px", color: "#595959" }}>
              Create Ticket
            </Title>
            <Text type="secondary">Coming Soon</Text>
          </div>
        );
      default:
        return null;
    }
  };

  const navigationItems = [
    {
      key: "tickets",
      icon: <FileTextOutlined style={{ fontSize: "20px" }} />,
      label: "Tickets",
    },
    {
      key: "groups",
      icon: <TeamOutlined style={{ fontSize: "20px" }} />,
      label: "Groups",
    },
    {
      key: "queues",
      icon: <InboxOutlined style={{ fontSize: "20px" }} />,
      label: "Queues",
    },
    {
      key: "members",
      icon: <UserOutlined style={{ fontSize: "20px" }} />,
      label: "Members",
    },
    {
      key: "create",
      icon: <PlusCircleOutlined style={{ fontSize: "20px" }} />,
      label: "Create",
    },
  ];

  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        height: "calc(100vh - 64px)",
      }}
    >
      {/* Header */}
      <div style={{ padding: "12px", borderBottom: "1px solid #f0f0f0" }}>
        <Button
          type="link"
          icon={<ArrowLeftOutlined />}
          onClick={() => navigate("/")}
          style={{ paddingLeft: 0, marginBottom: "8px" }}
          size="small"
        >
          Back
        </Button>
        <Title level={5} style={{ margin: 0 }}>
          {family.family_name}
        </Title>
        {family.family_description && (
          <Text type="secondary" style={{ fontSize: "11px" }}>
            {family.family_description}
          </Text>
        )}
      </div>

      {/* Content */}
      <div style={{ flex: 1, overflow: "auto", padding: "12px" }}>
        <Card>{renderContent()}</Card>
      </div>

      {/* Bottom Navigation */}
      <div
        style={{
          position: "fixed",
          bottom: 0,
          left: 0,
          right: 0,
          backgroundColor: "#fff",
          borderTop: "1px solid #f0f0f0",
          display: "flex",
          justifyContent: "space-around",
          padding: "8px 0",
          zIndex: 100,
        }}
      >
        {navigationItems.map((item) => (
          <button
            key={item.key}
            onClick={() => handleSectionChange(item.key)}
            style={{
              flex: 1,
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              gap: "4px",
              background: "none",
              border: "none",
              cursor: "pointer",
              padding: "8px",
              color: activeSection === item.key ? "#1890ff" : "#8c8c8c",
              transition: "color 0.3s",
            }}
          >
            <div>{item.icon}</div>
            <Text
              style={{
                fontSize: "11px",
                margin: 0,
                color: activeSection === item.key ? "#1890ff" : "#8c8c8c",
              }}
            >
              {item.label}
            </Text>
          </button>
        ))}
      </div>
    </div>
  );
};

export default FamilyPageMobile;
