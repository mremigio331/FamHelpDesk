import React from "react";
import { BrowserRouter as Router, Routes, Route } from "react-router-dom";
import { Layout } from "antd";
import Home from "./pages/home/Home";
import UserProfile from "./pages/user/UserProfile";
import EditProfilePage from "./pages/user/EditProfilePage";
import FamilyPage from "./pages/family/FamilyPage";
import CreateFamilyPage from "./pages/family/CreateFamilyPage";
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
            <Route path="/family/create" element={<CreateFamilyPage />} />
            <Route path="/family/:familyId" element={<FamilyPage />} />
          </Routes>
        </Content>
      </Layout>
    </Router>
  );
};

export default FamHelpDesk;
