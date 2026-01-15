import React, { useState } from "react";
import { Card, List, Typography, Empty, Spin, Alert, Tabs, Button, Space } from "antd";
import { UserOutlined, ClockCircleOutlined, UserAddOutlined } from "@ant-design/icons";
import useGetGroupMembers from "../../../hooks/group/membership/useGetGroupMembers";
import useGetGroupMembershipRequests from "../../../hooks/group/membership/useGetGroupMembershipRequests";
import useReviewGroupMembership from "../../../hooks/group/membership/useReviewGroupMembership";
import useRemoveGroupMember from "../../../hooks/group/membership/useRemoveGroupMember";
import useUpdateGroupMemberRole from "../../../hooks/group/membership/useUpdateGroupMemberRole";
import {
  handleApproveGroupMembership,
  handleRejectGroupMembership,
  handleRemoveGroupMember,
  handleToggleGroupMemberRole,
} from "./groupMembershipUtils";
import GroupMemberListItem from "./GroupMemberListItem";
import GroupMembershipRequestListItem from "./GroupMembershipRequestListItem";
import AddGroupMemberModal from "./AddGroupMemberModal";

const GroupMembersDesktop = ({ familyId, groupId, isAdmin }) => {
  const [activeTab, setActiveTab] = useState("members");
  const [isAddMemberModalVisible, setIsAddMemberModalVisible] = useState(false);

  const {
    members,
    memberCount,
    isFetchingMembers,
    isMembersError,
    refetchMembers,
  } = useGetGroupMembers(familyId, groupId);

  const {
    requests,
    requestCount,
    isFetchingRequests,
    isRequestsError,
    refetchRequests,
  } = useGetGroupMembershipRequests(familyId, groupId);

  const { reviewMembership, isReviewingMembership } =
    useReviewGroupMembership();

  const { removeMember, isRemovingMember } = useRemoveGroupMember();

  const { updateMemberRole, isUpdatingRole } = useUpdateGroupMemberRole();

  const handleApprove = (targetUserId, displayName) => {
    handleApproveGroupMembership(
      reviewMembership,
      familyId,
      groupId,
      targetUserId,
      displayName,
    );
    // Refetch after a short delay to allow backend to update
    setTimeout(() => {
      refetchRequests();
      refetchMembers();
    }, 500);
  };

  const handleReject = (targetUserId, displayName) => {
    handleRejectGroupMembership(
      reviewMembership,
      familyId,
      groupId,
      targetUserId,
      displayName,
    );
    // Refetch after a short delay to allow backend to update
    setTimeout(() => {
      refetchRequests();
    }, 500);
  };

  const handleRemove = (targetUserId, displayName) => {
    handleRemoveGroupMember(
      removeMember,
      familyId,
      groupId,
      targetUserId,
      displayName,
    );
    // Refetch after a short delay to allow backend to update
    setTimeout(() => {
      refetchMembers();
    }, 500);
  };

  const handleToggleAdmin = (targetUserId, currentIsAdmin, displayName) => {
    handleToggleGroupMemberRole(
      updateMemberRole,
      familyId,
      groupId,
      targetUserId,
      currentIsAdmin,
      displayName,
    );
    // Refetch after a short delay to allow backend to update
    setTimeout(() => {
      refetchMembers();
    }, 500);
  };

  const handleAddMemberSuccess = () => {
    // Refetch members after adding
    setTimeout(() => {
      refetchMembers();
    }, 500);
  };

  return (
    <>
      <Card>
        <Tabs
          activeKey={activeTab}
          onChange={setActiveTab}
          tabBarExtraContent={
            isAdmin && activeTab === "members" ? (
              <Button
                type="primary"
                icon={<UserAddOutlined />}
                onClick={() => setIsAddMemberModalVisible(true)}
              >
                Add Member
              </Button>
            ) : null
          }
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
                      description="Failed to load group members. Please try again."
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
                        <GroupMemberListItem
                          member={member}
                          isAdmin={isAdmin}
                          isCurrentUser={member.is_current_user}
                          isUpdatingRole={isUpdatingRole}
                          isRemovingMember={isRemovingMember}
                          onToggleAdmin={handleToggleAdmin}
                          onRemoveMember={handleRemove}
                        />
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
                  {!isAdmin ? (
                    <Alert
                      message="Admin Only"
                      description="Only group admins can view and manage membership requests."
                      type="info"
                      showIcon
                    />
                  ) : isFetchingRequests ? (
                    <div style={{ textAlign: "center", padding: "40px" }}>
                      <Spin size="large" />
                    </div>
                  ) : isRequestsError ? (
                    <Alert
                      message="Error Loading Requests"
                      description="Failed to load membership requests. Please try again."
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
                        <GroupMembershipRequestListItem
                          request={request}
                          isAdmin={isAdmin}
                          isReviewing={isReviewingMembership}
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

      <AddGroupMemberModal
        visible={isAddMemberModalVisible}
        onClose={() => setIsAddMemberModalVisible(false)}
        familyId={familyId}
        groupId={groupId}
        currentGroupMembers={members}
        onSuccess={handleAddMemberSuccess}
      />
    </>
  );
};

export default GroupMembersDesktop;
