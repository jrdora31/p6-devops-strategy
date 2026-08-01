import { TestBed } from '@angular/core/testing';

import { PersonService } from './person.service';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { API_BASE_URL } from './config';

describe('PersonService', () => {
  let service: PersonService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule]
    });
    service = TestBed.inject(PersonService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  it('should fetch all persons from the API', async () => {
    const persons = [{ id: 1, firstName: 'John', lastName: 'Doe' }];
    const resultPromise = service.fetchAll();
    await Promise.resolve();

    const request = http.expectOne(`${API_BASE_URL}/persons`);
    expect(request.request.method).toBe('GET');
    request.flush({ _embedded: { persons } });

    expect(await resultPromise).toEqual(persons as any);
  });

  it('should delete a person through the API', async () => {
    const resultPromise = service.deleteById(42);
    await Promise.resolve();

    const request = http.expectOne(`${API_BASE_URL}/persons/42`);
    expect(request.request.method).toBe('DELETE');
    request.flush(null);

    await resultPromise;
  });
});
