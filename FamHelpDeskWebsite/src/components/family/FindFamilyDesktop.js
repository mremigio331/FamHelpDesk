import React from "react";
import { Card, Typography, Button, Space, Spin, Alert, Input } from "antd";
import {
  ArrowLeftOutlined,
  SearchOutlined,
  UserAddOutlined,
} from "@ant-design/icons";
import FamilyList from "./FamilyList";
import { useFindFamily } from "./useFindFamily";

const { Title, Text } = Typography;
const { Search } = Input;

const FindFamilyDesktop = ({
  navigate,
  families,
  isFamiliesFetching,
  isFamiliesError,
  familiesError,
  myFamilies,
  requestFamilyMembership,
  isRequesting,
}) => {
  const {
    searchQuery,
    setSearchQuery,
    memberFamilies,
    availableFamilies,
    createFamilyActions,
  } = useFindFamily({
    families,
    myFamilies,
    requestFamilyMembership,
    isRequesting,
  });

  const renderFamilyActions = (family, membership) => {
    const actions = createFamilyActions(family, navigate);

    if (actions.isMember) {
      return [
        <Button type="link" onClick={actions.onView}>
          View
        </Button>,
      ];
    }

    return [
      <Button
        type="primary"
        icon={<UserAddOutlined />}
        onClick={actions.onRequestJoin}
        disabled={actions.isDisabled}
        loading={isRequesting}
      >
        {actions.buttonText}
      </Button>,
    ];
  };

  if (isFamiliesFetching) {
    return (
      <div style={{ padding: "50px", textAlign: "center" }}>
        <Spin size="large" />
      </div>
    );
  }

  if (isFamiliesError) {
    return (
      <div style={{ padding: "50px", maxWidth: "800px", margin: "0 auto" }}>
        <Alert
          message="Error"
          description={familiesError?.message || "Failed to load families"}
          type="error"
          showIcon
        />
      </div>
    );
  }

  return (
    <div style={{ padding: "50px", maxWidth: "1200px", margin: "0 auto" }}>
      <Space direction="vertical" size="large" style={{ width: "100%" }}>
        <div>
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
          <Space direction="vertical" size="middle" style={{ width: "100%" }}>
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: "12px",
              }}
            >
              <SearchOutlined style={{ fontSize: "32px" }} />
              <Title level={2} style={{ margin: 0 }}>
                Find a Family
              </Title>
            </div>

            <Text type="secondary" style={{ fontSize: "16px" }}>
              Search for families to join. Request membership and wait for an
              admin to approve your request.
            </Text>

            <Search
              placeholder="Search families by name or description"
              allowClear
              enterButton
              size="large"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              prefix={<SearchOutlined />}
            />
          </Space>
        </Card>

        {memberFamilies.length > 0 && (
          <Card title="Your Families">
            <FamilyList
              families={memberFamilies}
              memberships={myFamilies}
              renderActions={renderFamilyActions}
              showCreatedDate={false}
            />
          </Card>
        )}

        <Card title="Available Families">
          <FamilyList
            families={availableFamilies}
            renderActions={renderFamilyActions}
            emptyDescription={
              searchQuery
                ? "No families found matching your search"
                : "No families available"
            }
            showCreatedDate={false}
          />
        </Card>
      </Space>
    </div>
  );
};

export default FindFamilyDesktop;
