/* global axios */
import ApiClient from './ApiClient';

class TicketsAPI extends ApiClient {
  constructor() {
    super('tickets', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  counts() {
    return axios.get(`${this.url}/counts`);
  }
}

export default new TicketsAPI();
