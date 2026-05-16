import React, { useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { Layout, Tabs, Button, Typography, Spin, Alert } from "antd";
import {
  ArrowLeftOutlined,
  UnorderedListOutlined,
  UserOutlined,
  TrophyOutlined,
  PlusOutlined,
} from "@ant-design/icons";
import { useMyFamilies } from "../../provider/MyFamiliesProvider";
import EmbolecBalance from "../../components/FamGrab/EmbolecBalance";
import GrabRequestList from "../../components/FamGrab/GrabRequestList";
import Leaderboard from "../../components/FamGrab/Leaderboard";
import CreateRequestModal from "../../components/FamGrab/CreateRequestModal";

const { Content } = Layout;
const { Title } = Typography;

const FamGrabPage = () => {
  const { familyId } = useParams();
  const navigate = useNavigate();
  const { myFamilies, isMyFamiliesFetching, isMyFamiliesError } =
    useMyFamilies();
  const [activeTab, setActiveTab] = useState("open");
  const [isCreateModalVisible, setIsCreateModalVisible] = useState(false);

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

  const { family } = familyData;

  const tabItems = [
    {
      key: "open",
      label: (
        <span>
          <UnorderedListOutlined /> Open Requests
        </span>
      ),
      children: (
        <GrabRequestList familyId={familyId} filter="open" />
      ),
    },
    {
      key: "my",
      label: (
        <span>
          <UserOutlined /> My Requests
        </span>
      ),
      children: (
        <GrabRequestList familyId={familyId} filter="my" />
      ),
    },
    {
      key: "leaderboard",
      label: (
        <span>
          <TrophyOutlined /> Leaderboard
        </span>
      ),
      children: <Leaderboard familyId={familyId} />,
    },
  ];

  return (
    <div style={{ padding: "24px" }}>
      <div style={{ maxWidth: "1200px", margin: "0 auto" }}>
        <div style={{ marginBottom: "16px" }}>
          <Button
            type="link"
            icon={<ArrowLeftOutlined />}
            onClick={() => navigate(`/family/${familyId}`)}
            style={{ paddingLeft: 0 }}
          >
            Back to {family.family_name}
          </Button>
        </div>

        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            marginBottom: "24px",
          }}
        >
          <Title level={2} style={{ margin: 0 }}>
            FamGrab
          </Title>
          <Button
            type="primary"
            icon={<PlusOutlined />}
            onClick={() => setIsCreateModalVisible(true)}
          >
            New Request
          </Button>
        </div>

        <EmbolecBalance familyId={familyId} />

        <Content style={{ marginTop: "24px" }}>
          <Tabs
            activeKey={activeTab}
            onChange={setActiveTab}
            items={tabItems}
            size="large"
          />
        </Content>

        <CreateRequestModal
          visible={isCreateModalVisible}
          onClose={() => setIsCreateModalVisible(false)}
          familyId={familyId}
        />
      </div>
    </div>
  );
};

export default FamGrabPage;
