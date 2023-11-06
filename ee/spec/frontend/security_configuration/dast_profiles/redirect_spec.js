import { returnToPreviousPageFactory } from 'ee/security_configuration/dast_profiles/redirect';
import { TEST_HOST } from 'helpers/test_constants';
import * as urlUtility from '~/lib/utils/url_utility';

const fullPath = '/group/project';
const profilesLibraryPath = `${fullPath}/-/security/configuration/dast_scans`;
const onDemandScansPath = `${fullPath}/-/on_demand_scans`;
const dastConfigPath = `${fullPath}/-/security/configuration/dast`;
const urlParamKey = 'site_profile_id';
const originalReferrer = document.referrer;

const allowedPaths = [onDemandScansPath, dastConfigPath];
const disallowedPaths = [profilesLibraryPath, fullPath];
const defaultRedirectionPath = profilesLibraryPath;

const params = {
  allowedPaths,
  profilesLibraryPath: defaultRedirectionPath,
  urlParamKey,
};

const factory = (id) => returnToPreviousPageFactory(params)(id);

const setReferrer = (value) => {
  Object.defineProperty(document, 'referrer', {
    value: new URL(value, TEST_HOST).href,
    configurable: true,
  });
};

const resetReferrer = () => {
  setReferrer(originalReferrer);
};

describe('DAST Profiles redirector', () => {
  describe('returnToPreviousPageFactory', () => {
    beforeEach(() => {
      jest.spyOn(urlUtility, 'redirectTo').mockImplementation();
    });

    describe('redirects to default page', () => {
      it('when no referrer is present', () => {
        factory();
        expect(urlUtility.redirectTo).toHaveBeenCalledWith(defaultRedirectionPath);
      });

      it.each(disallowedPaths)('when previous path is %s', (path) => {
        setReferrer(path);

        factory();
        expect(urlUtility.redirectTo).toHaveBeenCalledWith(defaultRedirectionPath);

        resetReferrer();
      });
    });

    describe('redirects to previous page', () => {
      describe.each(allowedPaths)('when previous path is %s', (path) => {
        beforeEach(() => {
          setReferrer(path);
        });

        afterEach(() => {
          resetReferrer();
        });

        it('without params', () => {
          factory();
          expect(urlUtility.redirectTo).toHaveBeenCalledWith(path);
        });

        it('with params', () => {
          factory({ id: 2 });
          expect(urlUtility.redirectTo).toHaveBeenCalledWith(
            `${TEST_HOST}${path}?site_profile_id=2`,
          );
        });
      });
    });
  });
});
