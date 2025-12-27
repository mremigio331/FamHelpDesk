import React, { createContext, useContext, useMemo } from "react";
import useGetMyFamilies from "../hooks/family/useGetMyFamilies";

const MyFamiliesContext = createContext();

export const MyFamiliesProvider = ({ children }) => {
  const {
    myFamilies,
    isMyFamiliesFetching,
    isMyFamiliesError,
    myFamiliesError,
    myFamiliesRefetch,
  } = useGetMyFamilies();

  const familiesArray = useMemo(() => Object.values(myFamilies), [myFamilies]);

  const value = useMemo(
    () => ({
      myFamilies,
      familiesArray,
      isMyFamiliesFetching,
      isMyFamiliesError,
      myFamiliesError,
      myFamiliesRefetch,
    }),
    [
      myFamilies,
      familiesArray,
      isMyFamiliesFetching,
      isMyFamiliesError,
      myFamiliesError,
      myFamiliesRefetch,
    ],
  );

  return (
    <MyFamiliesContext.Provider value={value}>
      {children}
    </MyFamiliesContext.Provider>
  );
};

export const useMyFamilies = () => {
  const context = useContext(MyFamiliesContext);
  if (!context) {
    throw new Error("useMyFamilies must be used within MyFamiliesProvider");
  }
  return context;
};

export default MyFamiliesProvider;
