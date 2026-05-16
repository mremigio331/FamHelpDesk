import React, { useContext } from "react";
import { useParams, Navigate } from "react-router-dom";
import { Space, Typography } from "antd";
import { UserOutlined } from "@ant-design/icons";
import { useMobileDetection } from "../../provider/MobileDetectionProvider";
import { useMyFamilies } from "../../provider/MyFamiliesProvider";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import ManageMembersDesktop from "../../components/family/membership/ManageMembersDesktop";
import ManageMembersMobile from "../../components/family/membership/ManageMembersMobile";

const { Title } = Typography;

const ManageMembersPage = () => {
  const { familyId } = useParams();
  const { isMobile } = useMobileDetection();
  const { myFamilies, familiesArray } = useMyFamilies();
  const { userId } = useContext(UserAuthenticationContext);

  // Check if user is admin of this family
  const family = familiesArray.find((f) => f.family_id === familyId);
  const isAdmin = family?.membership?.is_admin || false;

  // Redirect non-admins
  if (!isAdmin) {
    return <Navigate to={`/family/${familyId}`} replace />;
  }

  return (
    <div style={{ padding: isMobile ? "16px" : "24px" }}>
      <Space
        direction="vertical"
        size="large"
        style={{ width: "100%", maxWidth: 1200, margin: "0 auto" }}
      >
        {!isMobile && (
          <div>
            <Title level={2}>
              <UserOutlined /> Manage Family Members
            </Title>
          </div>
        )}

        {isMobile ? (
          <ManageMembersMobile familyId={familyId} currentUserId={userId} />
        ) : (
          <ManageMembersDesktop familyId={familyId} currentUserId={userId} />
        )}
      </Space>
    </div>
  );
};

export default ManageMembersPage;
