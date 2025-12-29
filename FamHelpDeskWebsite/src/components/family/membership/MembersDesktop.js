import React, { useState } from "react";
import { Card, List, Typography, Space, Empty, Spin, Alert, Tabs } from "antd";
import { UserOutlined, ClockCircleOutlined } from "@ant-design/icons";
import useGetFamilyMembershipRequests from "../../../hooks/membership/useGetFamilyMembershipRequests";
import useGetFamilyMembers from "../../../hooks/membership/useGetFamilyMembers";
import useReviewMembershipRequest from "../../../hooks/membership/useReviewMembershipRequest";
import {
  handleApproveMembership,
  handleRejectMembership,
} from "./membershipUtils";
import MemberListItem from "./MemberListItem";
import RequestListItem from "./RequestListItem";

const { Title } = Typography;

const MembersDesktop = ({ familyId, isAdmin }) => {
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
                    renderItem={(member) => <MemberListItem member={member} />}
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
                      <RequestListItem
                        request={request}
                        isAdmin={isAdmin}
                        isReviewing={isReviewing}
                        onApprove={handleApprove}
                        onReject={handleReject}
                      />
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
