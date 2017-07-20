package controllers

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"

	"github.com/gorilla/mux"
	"github.com/sensu/sensu-go/backend/authorization"
	"github.com/sensu/sensu-go/types"
)

func processRequest(c Controller, req *http.Request) *httptest.ResponseRecorder {
	router := mux.NewRouter()
	c.Register(router)
	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	return res
}

func newRequest(meth, url string, body io.Reader) *http.Request {
	req, _ := http.NewRequest("DELETE", fmt.Sprintf("/entities/entity1"), nil)
	req = requestWithDefaultContext(req)

	return req
}

func requestWithDefaultContext(req *http.Request) *http.Request {
	req = requestWithOrganization(req, "default")
	req = requestWithFullAccess(req)

	return req
}

func requestWithOrganization(r *http.Request, organization string) *http.Request {
	context := context.WithValue(
		r.Context(),
		types.OrganizationKey,
		organization,
	)

	return r.WithContext(context)
}

func requestWithFullAccess(r *http.Request) *http.Request {
	userRoles := []*types.Role{types.FixtureRole("test", "default")}
	context := context.WithValue(
		r.Context(),
		authorization.ContextRoleKey,
		userRoles,
	)

	return r.WithContext(context)
}
