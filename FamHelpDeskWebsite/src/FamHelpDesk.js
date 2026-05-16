import React from "react";
import { BrowserRouter as Router, Routes, Route } from "react-router-dom";
import { Layout } from "antd";
import Home from "./pages/home/Home";
import UserProfile from "./pages/user/UserProfile";
import EditProfilePage from "./pages/user/EditProfilePage";
import FamilyPageWrapper from "./components/family/FamilyPageWrapper";
import CreateFamilyPage from "./pages/family/CreateFamilyPage";
import FindFamilyPage from "./pages/family/FindFamilyPage";
import ManageMembersPage from "./pages/family/ManageMembersPage";
import GroupDetail from "./components/group/GroupDetailWrapper";
import QueueDetail from "./components/queue/QueueDetailWrapper";
import NotificationsPage from "./components/notifications/NotificationsPage";
import FamGrabPage from "./pages/FamGrab/FamGrabPage";
import UserReviewHistory from "./components/FamGrab/UserReviewHistory";
import NotFoundPage from "./pages/NotFoundPage";
import Navbar from "./components/Navbar";

const { Content } = Layout;

const FamHelpDesk = () => {
  return (
    <Router>
      <Layout style={{ minHeight: "100vh" }}>
        <Navbar />
        <Content style={{ marginTop: "64px" }}>
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/profile" element={<UserProfile />} />
            <Route path="/user/profile" element={<UserProfile />} />
            <Route path="/user/profile/edit" element={<EditProfilePage />} />
            <Route path="/notifications" element={<NotificationsPage />} />
            <Route path="/family/create" element={<CreateFamilyPage />} />
            <Route path="/family/find" element={<FindFamilyPage />} />
            <Route path="/family/:familyId" element={<FamilyPageWrapper />} />
            <Route
              path="/family/:familyId/manage-members"
              element={<ManageMembersPage />}
            />
            <Route
              path="/family/:familyId/group/:groupId"
              element={<GroupDetail />}
            />
            <Route
              path="/family/:familyId/queue/:queueId"
              element={<QueueDetail />}
            />
            <Route
              path="/family/:familyId/grab"
              element={<FamGrabPage />}
            />
            <Route
              path="/family/:familyId/grab/reviews/:userId"
              element={<UserReviewHistory />}
            />
            <Route path="*" element={<NotFoundPage />} />
          </Routes>
        </Content>
      </Layout>
    </Router>
  );
};

export default FamHelpDesk;
