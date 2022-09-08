import * as Types from '../types';

import gql from 'graphql-tag';
import { ObjectAttributeValuesFragmentDoc } from './objectAttributeValues.api';
export const UserDetailAttributesFragmentDoc = gql`
    fragment userDetailAttributes on User {
  id
  internalId
  firstname
  lastname
  fullname
  image
  email
  web
  vip
  phone
  mobile
  fax
  note
  objectAttributeValues {
    ...objectAttributeValues
  }
  organization {
    id
    internalId
    name
    ticketsCount {
      open
      closed
    }
  }
  ticketsCount {
    open
    closed
  }
}
    ${ObjectAttributeValuesFragmentDoc}`;