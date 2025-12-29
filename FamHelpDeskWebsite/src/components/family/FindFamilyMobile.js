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

const FindFamilyMobile = ({
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
        <Button
          type="link"
          size="small"
          style={{ fontSize: "12px" }}
          onClick={actions.onView}
        >
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
        size="small"
        style={{ fontSize: "11px" }}
      >
        {actions.isPending || actions.hasJustRequested ? "Sent" : "Join"}
      </Button>,
    ];
  };

  if (isFamiliesFetching) {
    return (
      <div style={{ padding: "16px", textAlign: "center" }}>
        <Spin />
      </div>
    );
  }

  if (isFamiliesError) {
    return (
      <div style={{ padding: "16px", maxWidth: "800px", margin: "0 auto" }}>
        <Alert
          message="Error"
          description={familiesError?.message || "Failed to load families"}
          type="error"
          showIcon
          style={{ fontSize: "12px" }}
        />
      </div>
    );
  }

  return (
    <div style={{ padding: "16px", maxWidth: "1200px", margin: "0 auto" }}>
      <Space direction="vertical" size="middle" style={{ width: "100%" }}>
        <div>
          <Button
            type="link"
            icon={<ArrowLeftOutlined />}
            onClick={() => navigate("/")}
            style={{ paddingLeft: 0, fontSize: "12px" }}
          >
            Back to Home
          </Button>
        </div>

        <Card bodyStyle={{ padding: "12px" }}>
          <Space direction="vertical" size="small" style={{ width: "100%" }}>
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: "8px",
              }}
            >
              <SearchOutlined style={{ fontSize: "20px" }} />
              <Title level={4} style={{ margin: 0, fontSize: "16px" }}>
                Find a Family
              </Title>
            </div>

            <Text
              type="secondary"
              style={{ fontSize: "12px", lineHeight: "1.4" }}
            >
              Search for families to join. Request membership and wait for an
              admin to approve your request.
            </Text>

            <Search
              placeholder="Search families..."
              allowClear
              enterButton
              size="middle"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              prefix={<SearchOutlined />}
              style={{ fontSize: "12px" }}
            />
          </Space>
        </Card>

        {memberFamilies.length > 0 && (
          <Card
            title={<span style={{ fontSize: "14px" }}>Your Families</span>}
            bodyStyle={{ padding: "12px" }}
          >
            <FamilyList
              families={memberFamilies}
              memberships={myFamilies}
              renderActions={renderFamilyActions}
              showCreatedDate={false}
            />
          </Card>
        )}

        <Card
          title={<span style={{ fontSize: "14px" }}>Available Families</span>}
          bodyStyle={{ padding: "12px" }}
        >
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

export default FindFamilyMobile;
