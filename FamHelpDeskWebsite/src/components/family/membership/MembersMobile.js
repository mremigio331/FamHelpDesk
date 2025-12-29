import React, { useState } from "react";
import { List, Typography, Space, Empty, Spin, Alert, Segmented } from "antd";
import { UserOutlined, ClockCircleOutlined } from "@ant-design/icons";
import useGetFamilyMembershipRequests from "../../../hooks/membership/useGetFamilyMembershipRequests";
import useGetFamilyMembers from "../../../hooks/membership/useGetFamilyMembers";
import useReviewMembershipRequest from "../../../hooks/membership/useReviewMembershipRequest";
import {
  handleApproveMembership,
  handleRejectMembership,
} from "./membershipUtils";
import MemberCardMobile from "./MemberCardMobile";
import RequestCardMobile from "./RequestCardMobile";

const { Title } = Typography;

const MembersMobile = ({ familyId, isAdmin }) => {
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

  const { reviewMembership, isReviewing } =
    useReviewMembershipRequest(familyId);

  const handleApprove = (targetUserId, displayName) => {
    handleApproveMembership(reviewMembership, targetUserId, displayName);
  };

  const handleReject = (targetUserId, displayName) => {
    handleRejectMembership(reviewMembership, targetUserId, displayName);
  };

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
        <Space direction="vertical" size="small" style={{ width: "100%" }}>
          {members.map((member) => (
            <MemberCardMobile key={member.user_id} member={member} />
          ))}
        </Space>
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
      <Space direction="vertical" size="small" style={{ width: "100%" }}>
        {requests.map((request) => (
          <RequestCardMobile
            key={request.user_id}
            request={request}
            isAdmin={isAdmin}
            isReviewing={isReviewing}
            onApprove={handleApprove}
            onReject={handleReject}
          />
        ))}
      </Space>
    );
  };

  return (
    <Space direction="vertical" size="medium" style={{ width: "100%" }}>
      <Segmented
        value={activeTab}
        onChange={setActiveTab}
        options={[
          {
            label: `Members ${memberCount > 0 ? `(${memberCount})` : ""}`,
            value: "members",
            icon: <UserOutlined />,
          },
          {
            label: `Requests ${requestCount > 0 ? `(${requestCount})` : ""}`,
            value: "requests",
            icon: <ClockCircleOutlined />,
          },
        ]}
        block
        style={{ fontSize: "12px" }}
      />
      {renderContent()}
    </Space>
  );
};

export default MembersMobile;
