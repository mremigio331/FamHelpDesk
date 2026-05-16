import React, { useState, useMemo } from "react";
import {
  Space,
  Select,
  DatePicker,
  Button,
  Spin,
  Empty,
  Alert,
} from "antd";
import { useRequests } from "../../hooks/useFamGrab";
import useGetFamilyMembers from "../../hooks/membership/useGetFamilyMembers";
import GrabRequestCard from "./GrabRequestCard";
import GrabRequestDetail from "./GrabRequestDetail";

const { RangePicker } = DatePicker;

const statusOptions = [
  { value: "", label: "All Statuses" },
  { value: "OPEN", label: "Open" },
  { value: "CLAIMED", label: "Claimed" },
  { value: "COMPLETED", label: "Completed" },
  { value: "CONFIRMED", label: "Confirmed" },
  { value: "CANCELLED", label: "Cancelled" },
];

const roleOptions = [
  { value: "", label: "All Roles" },
  { value: "requestor", label: "My Requests" },
  { value: "claimer", label: "Claimed by Me" },
];

const GrabRequestList = ({ familyId, filter }) => {
  const [statusFilter, setStatusFilter] = useState(
    filter === "open" ? "OPEN" : "",
  );
  const [roleFilter, setRoleFilter] = useState(
    filter === "my" ? "requestor" : "",
  );
  const [dateRange, setDateRange] = useState(null);
  const [selectedRequestId, setSelectedRequestId] = useState(null);

  const params = {};
  if (statusFilter) params.status = statusFilter;
  if (roleFilter) params.user_role = roleFilter;
  if (dateRange && dateRange[0]) {
    params.start_date = Math.floor(dateRange[0].valueOf() / 1000);
  }
  if (dateRange && dateRange[1]) {
    params.end_date = Math.floor(dateRange[1].valueOf() / 1000);
  }

  const { requests, lastKey, isRequestsFetching, isRequestsError, refetchRequests } =
    useRequests(familyId, params);
  const { members } = useGetFamilyMembers(familyId);

  const memberNameMap = useMemo(() => {
    const map = {};
    if (members && members.length > 0) {
      members.forEach((m) => {
        map[m.user_id] = m.user_display_name || m.user_email || m.user_id;
      });
    }
    return map;
  }, [members]);

  const getDisplayName = (ref) => {
    if (!ref) return "Unknown";
    if (typeof ref === "object" && ref.name) return ref.name;
    if (typeof ref === "object" && ref.id) return memberNameMap[ref.id] || ref.id;
    return memberNameMap[ref] || ref;
  };

  if (selectedRequestId) {
    return (
      <GrabRequestDetail
        familyId={familyId}
        requestId={selectedRequestId}
        onBack={() => {
          setSelectedRequestId(null);
          refetchRequests();
        }}
      />
    );
  }

  return (
    <div>
      <Space wrap style={{ marginBottom: "16px" }}>
        <Select
          value={statusFilter}
          onChange={setStatusFilter}
          options={statusOptions}
          style={{ width: 140 }}
          placeholder="Status"
        />
        <Select
          value={roleFilter}
          onChange={setRoleFilter}
          options={roleOptions}
          style={{ width: 150 }}
          placeholder="Role"
        />
        <RangePicker
          onChange={(dates) => setDateRange(dates)}
          value={dateRange}
        />
      </Space>

      {isRequestsError && (
        <Alert
          message="Failed to load requests"
          type="error"
          showIcon
          style={{ marginBottom: "16px" }}
        />
      )}

      {isRequestsFetching && requests.length === 0 ? (
        <div style={{ textAlign: "center", padding: "40px" }}>
          <Spin size="large" />
        </div>
      ) : requests.length === 0 ? (
        <Empty description="No requests found" />
      ) : (
        <div>
          <Space direction="vertical" style={{ width: "100%" }} size="middle">
            {requests.map((request) => (
              <GrabRequestCard
                key={request.request_id}
                request={request}
                onClick={() => setSelectedRequestId(request.request_id)}
                getDisplayName={getDisplayName}
              />
            ))}
          </Space>

          {lastKey && (
            <div style={{ textAlign: "center", marginTop: "16px" }}>
              <Button onClick={() => refetchRequests()}>Load More</Button>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default GrabRequestList;
