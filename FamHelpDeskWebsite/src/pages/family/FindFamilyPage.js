import React, { useState } from "react";
import {
  Card,
  Typography,
  Button,
  Space,
  Spin,
  Alert,
  Input,
  Tag,
  message,
} from "antd";
import {
  ArrowLeftOutlined,
  SearchOutlined,
  UserAddOutlined,
} from "@ant-design/icons";
import { useNavigate } from "react-router-dom";
import useGetAllFamilies from "../../hooks/family/useGetAllFamilies";
import useRequestFamilyMembership from "../../hooks/family/useRequestFamilyMembership";
import { useMyFamilies } from "../../provider/MyFamiliesProvider";
import FamilyList from "../../components/family/FamilyList";
import { isActualMember, hasPendingRequest } from "../../utility/familyUtils";

const { Title, Text } = Typography;
const { Search } = Input;

const FindFamilyPage = () => {
  const navigate = useNavigate();
  const [searchQuery, setSearchQuery] = useState("");
  const { families, isFamiliesFetching, isFamiliesError, familiesError } =
    useGetAllFamilies();
  const { myFamilies } = useMyFamilies();
  const {
    requestFamilyMembership,
    isRequesting,
    isRequestSuccess,
    isRequestError,
    requestError,
  } = useRequestFamilyMembership();

  const [requestedFamilies, setRequestedFamilies] = useState(new Set());

  const handleRequestMembership = (familyId) => {
    requestFamilyMembership(
      { familyId },
      {
        onSuccess: () => {
          message.success("Membership request sent successfully!");
          setRequestedFamilies((prev) => new Set([...prev, familyId]));
        },
        onError: (error) => {
          message.error(
            error?.response?.data?.detail || "Failed to request membership",
          );
        },
      },
    );
  };

  // Filter families based on search query
  const filteredFamilies = families.filter((family) => {
    const query = searchQuery.toLowerCase();
    return (
      family.family_name.toLowerCase().includes(query) ||
      (family.family_description &&
        family.family_description.toLowerCase().includes(query))
    );
  });

  // Separate families into member and non-member
  const { memberFamilies, availableFamilies } = filteredFamilies.reduce(
    (acc, family) => {
      // Only show in "Your Families" if they are an actual MEMBER (not AWAITING or DECLINED)
      if (isActualMember(family.family_id, myFamilies)) {
        acc.memberFamilies.push(family);
      } else {
        acc.availableFamilies.push(family);
      }
      return acc;
    },
    { memberFamilies: [], availableFamilies: [] },
  );

  // Render actions for family list items
  const renderFamilyActions = (family, membership) => {
    const isMember = isActualMember(family.family_id, myFamilies);
    const isPending = hasPendingRequest(family.family_id, myFamilies);
    const hasJustRequested = requestedFamilies.has(family.family_id);

    if (isMember) {
      return [
        <Button
          type="link"
          onClick={() => navigate(`/family/${family.family_id}`)}
        >
          View
        </Button>,
      ];
    }

    return [
      <Button
        type="primary"
        icon={<UserAddOutlined />}
        onClick={() => handleRequestMembership(family.family_id)}
        disabled={isPending || hasJustRequested}
        loading={isRequesting}
      >
        {isPending || hasJustRequested ? "Request Sent" : "Request to Join"}
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

        {/* Families you're already a member of */}
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

        {/* Available families to join */}
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

export default FindFamilyPage;
