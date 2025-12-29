import React from "react";
import { Card, Button, Space } from "antd";
import { ArrowLeftOutlined } from "@ant-design/icons";
import FamilyList from "../FamilyList";
import { useFindFamily } from "./useFindFamily";
import { SearchHeaderDesktop } from "./SearchHeader";
import {
  renderFamilyActionsDesktop,
  renderLoadingState,
  renderErrorState,
} from "./findFamilyUtils";

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
    return renderFamilyActionsDesktop(family, actions, isRequesting);
  };

  if (isFamiliesFetching) {
    return renderLoadingState(false);
  }

  if (isFamiliesError) {
    return renderErrorState(familiesError, false);
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

        <SearchHeaderDesktop
          searchQuery={searchQuery}
          setSearchQuery={setSearchQuery}
        />

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
