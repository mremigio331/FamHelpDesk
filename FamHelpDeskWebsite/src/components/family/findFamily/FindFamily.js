import React from "react";
import { useNavigate } from "react-router-dom";
import { useMobileDetection } from "../../../provider/MobileDetectionProvider";
import useGetAllFamilies from "../../../hooks/family/useGetAllFamilies";
import useRequestFamilyMembership from "../../../hooks/family/useRequestFamilyMembership";
import { useMyFamilies } from "../../../provider/MyFamiliesProvider";
import FindFamilyDesktop from "./FindFamilyDesktop";
import FindFamilyMobile from "./FindFamilyMobile";

const FindFamily = () => {
  const navigate = useNavigate();
  const { isMobile } = useMobileDetection();
  const { families, isFamiliesFetching, isFamiliesError, familiesError } =
    useGetAllFamilies();
  const { myFamilies } = useMyFamilies();
  const { requestFamilyMembership, isRequesting } =
    useRequestFamilyMembership();

  const props = {
    navigate,
    families,
    isFamiliesFetching,
    isFamiliesError,
    familiesError,
    myFamilies,
    requestFamilyMembership,
    isRequesting,
  };

  return isMobile ? (
    <FindFamilyMobile {...props} />
  ) : (
    <FindFamilyDesktop {...props} />
  );
};

export default FindFamily;
