import React from "react";
import { Card, Button, Space } from "antd";
import { ArrowLeftOutlined } from "@ant-design/icons";
import FamilyList from "../FamilyList";
import { useFindFamily } from "./useFindFamily";
import { SearchHeaderMobile } from "./SearchHeader";
import {
  renderFamilyActionsMobile,
  renderLoadingState,
  renderErrorState,
} from "./findFamilyUtils";

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
    return renderFamilyActionsMobile(family, actions, isRequesting);
  };

  if (isFamiliesFetching) {
    return renderLoadingState(true);
  }

  if (isFamiliesError) {
    return renderErrorState(familiesError, true);
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

        <SearchHeaderMobile
          searchQuery={searchQuery}
          setSearchQuery={setSearchQuery}
        />

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
