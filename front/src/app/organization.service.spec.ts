import { TestBed } from '@angular/core/testing';

import { OrganizationService } from './organization.service';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { API_BASE_URL } from './config';

describe('OrganizationService', () => {
  let service: OrganizationService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule]
    });
    service = TestBed.inject(OrganizationService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  it('should fetch all organizations from the API', async () => {
    const organizations = [{ id: 1, name: 'Orion' }];
    const resultPromise = service.fetchAll();
    await Promise.resolve();

    const request = http.expectOne(`${API_BASE_URL}/organizations`);
    expect(request.request.method).toBe('GET');
    request.flush({ _embedded: { organizations } });

    expect(await resultPromise).toEqual(organizations as any);
  });

  it('should add a person using a URI list', async () => {
    const resultPromise = service.addPerson(7, 42);
    await Promise.resolve();

    const request = http.expectOne(`${API_BASE_URL}/organizations/7/persons`);
    expect(request.request.method).toBe('PUT');
    expect(request.request.headers.get('Content-Type')).toBe('text/uri-list');
    expect(request.request.body).toBe(`${API_BASE_URL}/persons/42`);
    request.flush(null);

    await resultPromise;
  });
});
