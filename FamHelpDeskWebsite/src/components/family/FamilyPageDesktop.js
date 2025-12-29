import React from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
  Layout,
  Menu,
  Card,
  Typography,
  Button,
  Space,
  Spin,
  Alert,
} from "antd";
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
import MembersDesktop from "./MembersDesktop";

const { Sider, Content } = Layout;
const { Title, Text } = Typography;

const FamilyPageDesktop = () => {
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
      <div style={{ padding: "50px", maxWidth: "600px", margin: "0 auto" }}>
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
      <div style={{ padding: "50px", maxWidth: "600px", margin: "0 auto" }}>
        <Alert
          message="Family Not Found"
          description="You do not have access to this family or it does not exist."
          type="warning"
          showIcon
          action={
            <Button type="primary" onClick={() => navigate("/")}>
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
      <div style={{ padding: "24px" }}>
        <div style={{ maxWidth: "800px", margin: "0 auto" }}>
          <div style={{ marginBottom: "24px" }}>
            <Button
              type="link"
              icon={<ArrowLeftOutlined />}
              onClick={() => navigate("/")}
              style={{ paddingLeft: 0 }}
            >
              Back to Home
            </Button>
          </div>

          <Card>
            <Alert
              message="Membership Pending"
              description="Your membership request is pending approval. You will gain access to this family once an admin approves your request."
              type="info"
              showIcon
              style={{ marginBottom: "24px" }}
            />

            <Space direction="vertical" size="large" style={{ width: "100%" }}>
              <div>
                <Title level={2} style={{ marginBottom: "8px" }}>
                  {family.family_name}
                </Title>
                {family.family_description && (
                  <Text type="secondary" style={{ fontSize: "16px" }}>
                    {family.family_description}
                  </Text>
                )}
              </div>
            </Space>
          </Card>
        </div>
      </div>
    );
  }

  const menuItems = [
    {
      key: "tickets",
      icon: <FileTextOutlined />,
      label: "Tickets",
    },
    {
      key: "groups",
      icon: <TeamOutlined />,
      label: "Groups",
    },
    {
      key: "queues",
      icon: <InboxOutlined />,
      label: "Queues",
    },
    {
      key: "members",
      icon: <UserOutlined />,
      label: "Members",
    },
    {
      key: "create",
      icon: <PlusCircleOutlined />,
      label: "Create Ticket",
    },
  ];

  const renderContent = () => {
    switch (activeSection) {
      case "tickets":
        return (
          <Card>
            <div style={{ textAlign: "center", padding: "60px 20px" }}>
              <FileTextOutlined
                style={{ fontSize: "64px", color: "#bfbfbf" }}
              />
              <Title level={3} style={{ marginTop: "16px", color: "#595959" }}>
                Tickets
              </Title>
              <Text type="secondary" style={{ fontSize: "16px" }}>
                Coming Soon
              </Text>
            </div>
          </Card>
        );
      case "groups":
        return (
          <Card>
            <div style={{ textAlign: "center", padding: "60px 20px" }}>
              <TeamOutlined style={{ fontSize: "64px", color: "#bfbfbf" }} />
              <Title level={3} style={{ marginTop: "16px", color: "#595959" }}>
                Groups
              </Title>
              <Text type="secondary" style={{ fontSize: "16px" }}>
                Coming Soon
              </Text>
            </div>
          </Card>
        );
      case "queues":
        return (
          <Card>
            <div style={{ textAlign: "center", padding: "60px 20px" }}>
              <InboxOutlined style={{ fontSize: "64px", color: "#bfbfbf" }} />
              <Title level={3} style={{ marginTop: "16px", color: "#595959" }}>
                Queues
              </Title>
              <Text type="secondary" style={{ fontSize: "16px" }}>
                Coming Soon
              </Text>
            </div>
          </Card>
        );
      case "members":
        return <MembersDesktop familyId={familyId} />;
      case "create":
        return (
          <Card>
            <div style={{ textAlign: "center", padding: "60px 20px" }}>
              <PlusCircleOutlined
                style={{ fontSize: "64px", color: "#bfbfbf" }}
              />
              <Title level={3} style={{ marginTop: "16px", color: "#595959" }}>
                Create Ticket
              </Title>
              <Text type="secondary" style={{ fontSize: "16px" }}>
                Coming Soon
              </Text>
            </div>
          </Card>
        );
      default:
        return null;
    }
  };

  return (
    <div style={{ padding: "24px" }}>
      <div style={{ maxWidth: "1400px", margin: "0 auto" }}>
        <div style={{ marginBottom: "24px" }}>
          <Button
            type="link"
            icon={<ArrowLeftOutlined />}
            onClick={() => navigate("/")}
            style={{ paddingLeft: 0 }}
          >
            Back to Home
          </Button>
        </div>

        <Layout
          style={{
            background: "transparent",
            minHeight: "calc(100vh - 200px)",
          }}
        >
          <Sider
            width={250}
            style={{
              background: "#fff",
              borderRadius: "8px",
              overflow: "hidden",
            }}
          >
            <div
              style={{
                padding: "20px",
                borderBottom: "1px solid #f0f0f0",
              }}
            >
              <Title level={4} style={{ margin: 0 }}>
                {family.family_name}
              </Title>
              {family.family_description && (
                <Text type="secondary" style={{ fontSize: "12px" }}>
                  {family.family_description}
                </Text>
              )}
            </div>
            <Menu
              mode="inline"
              selectedKeys={[activeSection]}
              items={menuItems}
              onClick={({ key }) => handleSectionChange(key)}
              style={{ border: "none" }}
            />
          </Sider>
          <Content style={{ marginLeft: "24px" }}>{renderContent()}</Content>
        </Layout>
      </div>
    </div>
  );
};

export default FamilyPageDesktop;
